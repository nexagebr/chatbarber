# frozen_string_literal: true

class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :set_scheduled_message, only: [:destroy]

  def index
    # Return pending + sent + failed so the frontend can show history
    @scheduled_messages = @conversation.scheduled_messages
                                       .where(status: %i[pending sent failed])
                                       .order(scheduled_at: :desc)
    render json: @scheduled_messages.map { |m| serialize(m) }
  end

  def create
    @scheduled_message = @conversation.scheduled_messages.new(
      content: params.dig(:scheduled_message, :content),
      scheduled_at: params.dig(:scheduled_message, :scheduled_at),
      account: Current.account,
      inbox_id: @conversation.inbox_id,
      user_id: Current.user&.id,
      status: :pending,
      template_params: {
        is_private: params.dig(:scheduled_message, :is_private) == 'true' || params.dig(:scheduled_message, :is_private) == true,
        signed_ids: Array(params.dig(:scheduled_message, :signed_ids)).map(&:to_s).reject(&:blank?),
      }
    )
    if @scheduled_message.save
      render json: serialize(@scheduled_message), status: :created
    else
      render json: { errors: @scheduled_message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @scheduled_message.update!(status: 'cancelled')
    head :no_content
  end

  def upload_attachment
    file = params[:file]
    return render json: { error: 'Nenhum arquivo enviado' }, status: :bad_request if file.blank?

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type
    )
    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s, id: blob.id }
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversa não encontrada' }, status: :not_found
  end

  def set_scheduled_message
    @scheduled_message = @conversation.scheduled_messages.pending.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Mensagem agendada não encontrada' }, status: :not_found
  end

  def serialize(msg)
    {
      id: msg.id,
      content: msg.content,
      scheduled_at: msg.scheduled_at,
      status: msg.status,
      is_private: msg.is_private?,
      signed_ids: msg.parsed_signed_ids,
      created_at: msg.created_at,
    }
  end
end
