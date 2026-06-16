class Api::V1::Accounts::KnowledgeBaseSitesController < Api::V1::Accounts::BaseController
  before_action :fetch_kb

  def index
    render json: @kb.sites.order(:created_at)
  end

  def create
    render json: @kb.sites.create!(site_params), status: :created
  end

  def destroy
    @kb.sites.find(params[:id]).destroy!
    head :ok
  end

  private

  def fetch_kb
    @kb = Current.account.knowledge_bases.find(params[:knowledge_basis_id])
  end

  def site_params
    params.require(:knowledge_base_site).permit(:url, :title)
  end
end
