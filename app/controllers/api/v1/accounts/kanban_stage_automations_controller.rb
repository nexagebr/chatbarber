# frozen_string_literal: true

class Api::V1::Accounts::KanbanStageAutomationsController < Api::V1::Accounts::BaseController
  before_action :set_stage

  def index
    automations = @stage.kanban_stage_automations.ordered
    render json: automations.map(&:as_json)
  end

  def create
    automation = @stage.kanban_stage_automations.new(automation_params.merge(account: Current.account))
    automation.position = @stage.kanban_stage_automations.maximum(:position).to_i + 1
    if automation.save
      render json: automation.as_json, status: :created
    else
      render json: { errors: automation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    automation = @stage.kanban_stage_automations.find(params[:id])
    if automation.update(automation_params)
      render json: automation.as_json
    else
      render json: { errors: automation.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not found' }, status: :not_found
  end

  def destroy
    automation = @stage.kanban_stage_automations.find(params[:id])
    automation.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def set_stage
    funnel = Current.account.kanban_funnels.find(params[:kanban_funnel_id])
    @stage = funnel.kanban_stages.find(params[:kanban_stage_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not found' }, status: :not_found
  end

  def automation_params
    params.require(:kanban_stage_automation).permit(
      :action_type, :delay_minutes, :active, :position,
      action_params: {}
    )
  end
end
