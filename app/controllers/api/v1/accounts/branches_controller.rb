class Api::V1::Accounts::BranchesController < Api::V1::Accounts::BaseController
  before_action :fetch_branch, only: [:show, :update, :destroy, :schedules]

  def index
    @branches = Current.account.branches.ordered.includes(:professionals, :branch_schedules)
    render json: @branches.map { |b| serialize(b) }
  end

  def show
    render json: serialize(@branch)
  end

  def create
    @branch = Current.account.branches.create!(branch_params)
    seed_schedules(@branch)
    assign_professionals(@branch)
    render json: serialize(@branch.reload), status: :created
  end

  def update
    @branch.update!(branch_params)
    assign_professionals(@branch)
    render json: serialize(@branch.reload)
  end

  def destroy
    @branch.destroy!
    head :no_content
  end

  def schedules
    schedules_data = params[:schedules]
    return head :unprocessable_entity unless schedules_data.is_a?(Array)

    schedules_data.each do |s|
      schedule = @branch.branch_schedules.find_or_initialize_by(day_of_week: s[:day_of_week])
      schedule.update!(active: s[:active], start_time: s[:start_time], end_time: s[:end_time])
    end
    render json: @branch.branch_schedules.order(:day_of_week)
  end

  private

  def fetch_branch
    @branch = Current.account.branches.find(params[:id])
  end

  def branch_params
    params.permit(:name, :address, :phone, :description, :active)
  end

  def assign_professionals(branch)
    return unless params[:professional_ids]
    ids = Array(params[:professional_ids]).map(&:to_i)
    branch.professional_ids = Current.account.professionals.where(id: ids).pluck(:id)
  end

  def seed_schedules(branch)
    7.times do |day|
      branch.branch_schedules.find_or_create_by!(day_of_week: day) do |s|
        s.active     = day.between?(1, 5)
        s.start_time = '09:00'
        s.end_time   = '18:00'
      end
    end
  end

  def serialize(branch)
    {
      id: branch.id,
      name: branch.name,
      address: branch.address,
      phone: branch.phone,
      description: branch.description,
      active: branch.active,
      professional_ids: branch.professionals.pluck(:id),
      professionals: branch.professionals.map { |p| { id: p.id, name: p.name, thumbnail: p.thumbnail } },
      branch_schedules: branch.branch_schedules.order(:day_of_week),
    }
  end
end
