class Api::V1::Accounts::KnowledgeBaseFilesController < Api::V1::Accounts::BaseController
  before_action :fetch_kb

  def index
    render json: @kb.files.order(:created_at)
  end

  def create
    render json: @kb.files.create!(file_params), status: :created
  end

  def destroy
    @kb.files.find(params[:id]).destroy!
    head :ok
  end

  private

  def fetch_kb
    @kb = Current.account.knowledge_bases.find(params[:knowledge_basis_id])
  end

  def file_params
    params.require(:knowledge_base_file).permit(:original_filename, :file_size, :content_type, :status)
  end
end
