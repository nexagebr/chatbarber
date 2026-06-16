# frozen_string_literal: true

class SendScheduledMessagesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ScheduledMessage.due.find_each(batch_size: 50) do |scheduled_msg|
      dispatch(scheduled_msg)
    end
  end

  private

  def dispatch(scheduled_msg)
    # Guard against orphaned records (conversation/account deleted after scheduling)
    unless scheduled_msg.conversation && scheduled_msg.account
      scheduled_msg.update_columns(status: 3) # failed = 3
      return
    end

    params = {
      content: scheduled_msg.content.presence,
      private: scheduled_msg.is_private?,
    }

    signed_ids = scheduled_msg.parsed_signed_ids
    params[:attachments] = signed_ids if signed_ids.any?

    Messages::MessageBuilder.new(nil, scheduled_msg.conversation, params.compact).perform
    scheduled_msg.update_columns(status: 1, sent_at: Time.current) # sent = 1
  rescue StandardError => e
    scheduled_msg.update_columns(status: 3) # failed = 3, bypasses validation
    ChatwootExceptionTracker.new(e, account: scheduled_msg.account).capture_exception rescue nil
  end
end
