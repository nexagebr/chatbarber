# frozen_string_literal: true

class Api::V1::Accounts::KanbanStageItemsController < Api::V1::Accounts::BaseController
  before_action :set_funnel

  def index
    items = @funnel.kanban_stage_items.includes(:conversation)
    render json: items.map { |i| serialize_item(i) }
  end

  def upsert
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    item = @funnel.kanban_stage_items.find_or_initialize_by(conversation_id: conversation.id)

    new_stage_id = params[:stage_id].present? ? params[:stage_id].to_i : nil
    stage_changed = item.new_record? || item.stage_id != new_stage_id

    attrs = { account: Current.account, stage_id: new_stage_id }
    attrs[:entered_at]   = Time.current if stage_changed
    attrs[:outcome_at]   = Time.current if stage_changed && new_stage_id
    attrs[:deal_value]   = params[:deal_value]   if params.key?(:deal_value)
    attrs[:loss_reason]  = params[:loss_reason]  if params.key?(:loss_reason)
    attrs[:outcome_note] = params[:outcome_note] if params.key?(:outcome_note)

    item.assign_attributes(attrs)

    if item.save
      if stage_changed && item.stage_id.present?
        ExecuteKanbanStageAutomationJob.enqueue_for_stage(
          item.stage_id, conversation.id, Current.account.id
        )
      end
      render json: serialize_item(item, conversation), status: item.previously_new_record? ? :created : :ok
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversa não encontrada' }, status: :not_found
  end

  def destroy
    conversation = Current.account.conversations.find_by(display_id: params[:id])
    item = conversation ? @funnel.kanban_stage_items.find_by(conversation_id: conversation.id) : nil
    if item
      item.destroy
      head :no_content
    else
      head :not_found
    end
  end

  private

  def set_funnel
    @funnel = Current.account.kanban_funnels.find(params[:kanban_funnel_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Funnel not found' }, status: :not_found
  end

  def serialize_item(item, conversation = nil)
    conversation ||= item.conversation
    {
      id: item.id,
      funnel_id: item.funnel_id,
      conversation_id: conversation.display_id,
      stage_id: item.stage_id,
      entered_at: item.entered_at,
      position: item.position,
      deal_value: item.deal_value,
      loss_reason: item.loss_reason,
      outcome_note: item.outcome_note,
      outcome_at: item.outcome_at
    }
  end
end
