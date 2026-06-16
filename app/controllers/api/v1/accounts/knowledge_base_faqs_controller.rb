class Api::V1::Accounts::KnowledgeBaseFaqsController < Api::V1::Accounts::BaseController
  before_action :fetch_kb

  def index
    faqs = @kb.faqs.ordered
    faqs = faqs.search(params[:search]) if params[:search].present?
    render json: faqs
  end

  def create
    render json: @kb.faqs.create!(faq_params), status: :created
  end

  def update
    faq = @kb.faqs.find(params[:id])
    faq.update!(faq_params)
    render json: faq
  end

  def destroy
    @kb.faqs.find(params[:id]).destroy!
    head :ok
  end

  private

  def fetch_kb
    @kb = Current.account.knowledge_bases.find(params[:knowledge_basis_id])
  end

  def faq_params
    params.require(:knowledge_base_faq).permit(:question, :answer, :category, :position)
  end
end
