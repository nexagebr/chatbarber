# frozen_string_literal: true

class Api::V1::Accounts::KanbanStagesController < Api::V1::Accounts::BaseController
  before_action :set_funnel
  before_action :set_kanban_stage, only: [:update, :destroy]

  def index
    @kanban_stages = @funnel.kanban_stages.ordered.includes(:label)
  end

  def create
    @kanban_stage = @funnel.kanban_stages.new(kanban_stage_params.merge(account: Current.account))
    if @kanban_stage.save
      render json: @kanban_stage, status: :created
    else
      render json: { errors: @kanban_stage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @kanban_stage.update(kanban_stage_params)
      render json: @kanban_stage
    else
      render json: { errors: @kanban_stage.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @kanban_stage.destroy
    head :no_content
  end

  def reorder
    params[:stages].each_with_index do |stage_data, _index|
      stage = @funnel.kanban_stages.find(stage_data[:id])
      stage.update(position: stage_data[:position])
    end

    @kanban_stages = @funnel.kanban_stages.ordered.includes(:label)
    render :index
  end

  private

  def set_funnel
    @funnel = Current.account.kanban_funnels.find(params[:kanban_funnel_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Funnel not found' }, status: :not_found
  end

  def set_kanban_stage
    @kanban_stage = @funnel.kanban_stages.find(params[:id])
  end

  def kanban_stage_params
    params.require(:kanban_stage).permit(:name, :color, :label_id, :position, :stage_type)
  end
end
