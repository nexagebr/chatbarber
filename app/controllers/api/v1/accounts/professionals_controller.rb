class Api::V1::Accounts::ProfessionalsController < Api::V1::Accounts::BaseController
  before_action :fetch_professional, only: [:show, :update, :destroy, :schedules, :blocked_dates, :breaks]

  def index
    @professionals = Current.account.professionals.ordered
    render json: @professionals.map(&:as_json)
  end

  def show
    render json: @professional.as_json
  end

  # POST /activate_agent  — toggle an agent as professional
  def activate_agent
    agent = Current.account.users.find(params[:agent_id])
    professional = Current.account.professionals.find_or_initialize_by(agent_id: agent.id)

    if professional.new_record?
      professional.assign_attributes(
        name: agent.name,
        email: agent.email,
        active: true,
      )
      professional.save!
      seed_schedules(professional)
    else
      professional.update!(active: params[:active].nil? ? !professional.active : ActiveModel::Type::Boolean.new.cast(params[:active]))
    end

    render json: professional.as_json
  end

  def create
    @professional = Current.account.professionals.create!(professional_params)
    seed_schedules(@professional)
    render json: @professional.as_json, status: :created
  end

  def update
    @professional.update!(professional_params)
    render json: @professional.as_json
  end

  def destroy
    @professional.destroy!
    head :no_content
  end

  def schedules
    schedules_data = params[:schedules]
    return head :unprocessable_entity unless schedules_data.is_a?(Array)

    schedules_data.each do |s|
      schedule = @professional.professional_schedules.find_or_initialize_by(day_of_week: s[:day_of_week])
      schedule.update!(active: s[:active], start_time: s[:start_time], end_time: s[:end_time])
    end
    render json: @professional.professional_schedules.order(:day_of_week)
  end

  def blocked_dates
    case request.method
    when 'GET'
      render json: @professional.professional_blocked_dates.order(:date)
    when 'POST'
      bd = @professional.professional_blocked_dates.create!(blocked_date_params)
      render json: bd, status: :created
    end
  end

  def delete_blocked_date
    professional = Current.account.professionals.find(params[:professional_id])
    bd = professional.professional_blocked_dates.find(params[:id])
    bd.destroy!
    head :no_content
  end

  # GET/POST/DELETE :breaks
  def breaks
    case request.method
    when 'GET'
      render json: @professional.professional_breaks.order(:day_of_week, :start_time)
    when 'POST'
      b = @professional.professional_breaks.create!(break_params)
      render json: b, status: :created
    when 'DELETE'
      b = @professional.professional_breaks.find(params[:break_id])
      b.destroy!
      head :no_content
    end
  end

  private

  def fetch_professional
    @professional = Current.account.professionals.find(params[:id])
  end

  def professional_params
    params.permit(:name, :email, :phone, :specialty, :commission_pct, :active, :agent_id, :color)
  end

  def blocked_date_params
    params.permit(:date, :start_time, :end_time, :reason)
  end

  def break_params
    params.permit(:day_of_week, :start_time, :end_time, :label)
  end

  def seed_schedules(professional)
    7.times do |day|
      professional.professional_schedules.find_or_create_by!(day_of_week: day) do |s|
        s.active     = day.between?(1, 5)
        s.start_time = '09:00'
        s.end_time   = '18:00'
      end
    end
  end
end
