# frozen_string_literal: true

# Account-scoped endpoint that returns Kanban placements for a given conversation
# OR all placements across all conversations of a given contact.
# Unlike kanban_stage_items (which is funnel-scoped), this is funnel-agnostic.
#
# GET /api/v1/accounts/:account_id/kanban_placements?conversation_id=<display_id>
# GET /api/v1/accounts/:account_id/kanban_placements?contact_id=<id>
#
# Response shape:
# {
#   placements: [ { id, funnel_id, funnel_name, conversation_id (display_id),
#                   conversation_label, stage_id, stage_name, stage_color, stage_type,
#                   deal_value, loss_reason, outcome_note, entered_at, outcome_at } ],
#   funnels:    [ { id, name, stages: [ { id, name, stage_type, color, position } ] } ]
# }
class Api::V1::Accounts::KanbanPlacementsController < Api::V1::Accounts::BaseController
  def index
    conversations = resolve_conversations
    return if conversations.nil?

    @placements = KanbanStageItem
                    .where(conversation_id: conversations.map(&:id))
                    .includes(:stage, :funnel, conversation: :contact)

    @funnels = Current.account.kanban_funnels
                       .includes(kanban_stages: {})
                       .order(:position)
  end

  private

  def resolve_conversations
    if params[:conversation_ids].present?
      ids = Array(params[:conversation_ids]).map(&:to_i).uniq
      Current.account.conversations.where(display_id: ids).to_a
    elsif params[:conversation_id].present?
      conv = Current.account.conversations.find_by(display_id: params[:conversation_id])
      if conv.nil?
        render json: { error: 'Conversa não encontrada' }, status: :not_found
        return nil
      end
      [conv]
    elsif params[:contact_id].present?
      contact = Current.account.contacts.find_by(id: params[:contact_id])
      if contact.nil?
        render json: { error: 'Contato não encontrado' }, status: :not_found
        return nil
      end
      Current.account.conversations.where(contact_id: contact.id).to_a
    else
      render json: { error: 'Parâmetro conversation_id, conversation_ids ou contact_id obrigatório' }, status: :bad_request
      nil
    end
  end
end
