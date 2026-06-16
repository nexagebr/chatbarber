class Api::V1::Accounts::ServicesController < Api::V1::Accounts::BaseController
  before_action :fetch_service, only: [:update, :destroy]

  def index
    @services = Current.account.barber_services.order(:name)
    render json: @services
  end

  def create
    @service = Current.account.barber_services.create!(service_params)
    render json: @service, status: :created
  end

  def update
    @service.update!(service_params)
    render json: @service
  end

  def destroy
    @service.destroy!
    head :no_content
  end

  private

  def fetch_service
    @service = Current.account.barber_services.find(params[:id])
  end

  def service_params
    params.permit(:name, :description, :duration_minutes, :price, :active)
  end
end
