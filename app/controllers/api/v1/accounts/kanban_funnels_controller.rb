# frozen_string_literal: true

class Api::V1::Accounts::KanbanFunnelsController < Api::V1::Accounts::BaseController
  before_action :set_funnel, only: [:update, :destroy]

  def index
    @funnels = Current.account.kanban_funnels.includes(:kanban_funnel_inboxes).ordered
    render json: @funnels.map { |f| funnel_json(f) }
  end

  def create
    @funnel = Current.account.kanban_funnels.new(funnel_params)
    if @funnel.save
      sync_inbox_ids(@funnel)
      render json: funnel_json(@funnel), status: :created
    else
      render json: { errors: @funnel.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @funnel.update(funnel_params)
      sync_inbox_ids(@funnel)
      render json: funnel_json(@funnel)
    else
      render json: { errors: @funnel.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @funnel.destroy
    head :no_content
  end

  private

  def set_funnel
    @funnel = Current.account.kanban_funnels.find(params[:id])
  end

  def funnel_params
    params.require(:kanban_funnel).permit(:name, :position, :show_unassigned)
  end

  def sync_inbox_ids(funnel)
    return unless params[:kanban_funnel].key?(:inbox_ids)

    ids = Array(params[:kanban_funnel][:inbox_ids]).map(&:to_i).uniq.select(&:positive?)
    valid_ids = Current.account.inboxes.where(id: ids).pluck(:id)
    funnel.kanban_funnel_inboxes.where.not(inbox_id: valid_ids).destroy_all
    existing = funnel.kanban_funnel_inboxes.pluck(:inbox_id)
    (valid_ids - existing).each { |iid| funnel.kanban_funnel_inboxes.create!(inbox_id: iid) }
  end

  def funnel_json(funnel)
    funnel.as_json(only: [:id, :name, :position, :show_unassigned]).merge(
      inbox_ids: funnel.kanban_funnel_inboxes.pluck(:inbox_id)
    )
  end
end
