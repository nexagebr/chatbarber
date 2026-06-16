class Api::V1::Accounts::AppointmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_appointment, only: [:show, :update, :destroy]

  def index
    @appointments = Current.account.appointments
                           .includes(:professional, :contact, :products)
                           .order(:scheduled_at)

    if params[:from].present? && params[:to].present?
      @appointments = @appointments.in_range(params[:from], params[:to])
    end

    @appointments = @appointments.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    @appointments = @appointments.where(status: params[:status]) if params[:status].present?
    @appointments = @appointments.where(branch_id: params[:branch_id]) if params[:branch_id].present?

    render json: @appointments.map { |a| serialize(a) }
  end

  def show
    render json: serialize(@appointment)
  end

  def create
    attrs = appointment_params
    @appointment = Current.account.appointments.create!(attrs)
    sync_services(@appointment)
    render json: serialize(@appointment.reload), status: :created
  end

  def update
    @appointment.update!(appointment_params)
    sync_services(@appointment)
    render json: serialize(@appointment.reload)
  end

  def destroy
    @appointment.destroy!
    head :no_content
  end

  private

  def fetch_appointment
    @appointment = Current.account.appointments.find(params[:id])
  end

  def appointment_params
    params.permit(:scheduled_at, :end_time, :professional_id, :contact_id, :branch_id,
                  :status, :notes, :location_type, :total_price, :title, :appointment_type,
                  :service_type)
  end

  def sync_services(appointment)
    return unless params[:service_ids].present?

    appointment.appointment_services.destroy_all
    Array(params[:service_ids]).map(&:to_i).each do |pid|
      # Try to find as a Product first (the main services tab)
      if Current.account.products.exists?(pid)
        appointment.appointment_services.create!(product_id: pid)
      end
    end
  end

  def serialize(a)
    # Gather services from products (primary) or legacy barber_services
    svc_list = if a.products.any?
      a.products.map do |p|
        { id: p.id, name: p.name, duration_minutes: p.duracao ? (p.duracao / 60).round : nil, price: p.price }
      end
    else
      a.services.map do |s|
        { id: s.id, name: s.name, duration_minutes: s.duration_minutes, price: s.price }
      end
    end

    {
      id: a.id,
      title: a.title.presence || svc_list.map { |s| s[:name] }.join(', '),
      scheduled_at: a.scheduled_at,
      end_time: a.end_time,
      status: a.status,
      notes: a.notes,
      location_type: a.location_type,
      total_price: a.total_price,
      branch_id: a.branch_id,
      professional: a.professional ? {
        id: a.professional.id,
        name: a.professional.name,
        thumbnail: a.professional.thumbnail,
      } : nil,
      contact: a.contact ? {
        id: a.contact.id,
        name: a.contact.name,
        phone_number: a.contact.phone_number,
        email: a.contact.email,
      } : nil,
      services: svc_list,
    }
  end
end
