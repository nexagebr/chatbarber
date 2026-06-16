# frozen_string_literal: true

class ExecuteKanbanStageAutomationJob < ApplicationJob
  queue_as :default

  # Called when a conversation enters a stage.
  # Enqueues each active automation (respecting delay_minutes).
  def self.enqueue_for_stage(stage_id, conversation_db_id, account_id)
    automations = KanbanStageAutomation.where(stage_id: stage_id, active: true).ordered
    automations.each do |automation|
      delay = automation.delay_minutes.to_i
      if delay > 0
        set(wait: delay.minutes).perform_later(automation.id, conversation_db_id, account_id, stage_id)
      else
        perform_later(automation.id, conversation_db_id, account_id, stage_id)
      end
    end
  end

  def perform(automation_id, conversation_db_id, account_id, required_stage_id)
    automation = KanbanStageAutomation.find_by(id: automation_id)
    account    = Account.find_by(id: account_id)
    return unless automation && account

    conversation = account.conversations.find_by(id: conversation_db_id)
    return unless conversation

    # For delayed automations, verify conversation is still in the same stage
    if automation.delay_minutes.to_i > 0
      item = KanbanStageItem.find_by(conversation_id: conversation_db_id)
      return unless item&.stage_id == required_stage_id
    end

    execute_action(automation, conversation, account)
  end

  private

  def execute_action(automation, conversation, account) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    params = automation.action_params || {}

    case automation.action_type
    when 'send_message'
      content = params['content'].presence
      return unless content

      Messages::MessageBuilder.new(nil, conversation, {
        content: content,
        private: params['is_private'] == true || params['is_private'] == 'true'
      }).perform

    when 'send_scheduled_message'
      content = params['content'].presence
      return unless content

      delay = (params['delay_minutes'] || 60).to_i
      ScheduledMessage.create!(
        account: account,
        conversation: conversation,
        inbox_id: conversation.inbox_id,
        content: content,
        scheduled_at: Time.current + delay.minutes,
        status: :pending,
        template_params: {
          is_private: params['is_private'] == true || params['is_private'] == 'true',
          signed_ids: []
        }
      )

    when 'add_label'
      label_title = params['label'].presence
      return unless label_title

      current = conversation.label_list
      conversation.label_list = (current + [label_title]).uniq
      conversation.save!

    when 'remove_label'
      label_title = params['label'].presence
      return unless label_title

      conversation.label_list = conversation.label_list - [label_title]
      conversation.save!

    when 'assign_agent'
      agent_id = params['agent_id']
      return unless agent_id

      agent = account.agents.find_by(id: agent_id)
      conversation.update!(assignee: agent) if agent

    when 'assign_team'
      team_id = params['team_id']
      return unless team_id

      team = account.teams.find_by(id: team_id)
      conversation.update!(team: team) if team

    when 'update_status'
      status = params['status'].presence
      return unless status && KanbanStageAutomation::STATUS_OPTIONS.include?(status)

      conversation.update_columns(status: Conversation.statuses[status])

    when 'update_priority'
      priority = params['priority']
      conversation.update!(priority: priority)

    when 'add_note'
      content = params['content'].presence
      return unless content

      Messages::MessageBuilder.new(nil, conversation, {
        content: content,
        private: true
      }).perform
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception rescue nil
  end
end
