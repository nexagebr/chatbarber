class Api::V1::Accounts::HolidaysController < Api::V1::Accounts::BaseController
  before_action :fetch_branch

  def index
    render json: @branch.holidays.ordered
  end

  def create
    holiday = @branch.holidays.find_or_initialize_by(date: params[:date])
    holiday.assign_attributes(name: params[:name], account: Current.account)
    holiday.save!
    render json: holiday, status: :created
  end

  def destroy
    holiday = @branch.holidays.find(params[:id])
    holiday.destroy!
    head :no_content
  end

  private

  def fetch_branch
    @branch = Current.account.branches.find(params[:branch_id])
  end
end
