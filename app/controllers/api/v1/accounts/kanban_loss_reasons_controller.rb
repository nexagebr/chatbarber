# frozen_string_literal: true

class Api::V1::Accounts::KanbanLossReasonsController < Api::V1::Accounts::BaseController
  def index
    reasons = Current.account.kanban_loss_reasons.ordered
    render json: reasons.map { |r| serialize(r) }
  end

  def create
    reason = Current.account.kanban_loss_reasons.new(reason_params)
    reason.position = Current.account.kanban_loss_reasons.maximum(:position).to_i + 1
    if reason.save
      render json: serialize(reason), status: :created
    else
      render json: { errors: reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    reason = Current.account.kanban_loss_reasons.find(params[:id])
    if reason.update(reason_params)
      render json: serialize(reason)
    else
      render json: { errors: reason.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not found' }, status: :not_found
  end

  def destroy
    reason = Current.account.kanban_loss_reasons.find(params[:id])
    reason.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def reason_params
    params.require(:kanban_loss_reason).permit(:name, :active, :position)
  end

  def serialize(reason)
    { id: reason.id, name: reason.name, active: reason.active, position: reason.position }
  end
end
