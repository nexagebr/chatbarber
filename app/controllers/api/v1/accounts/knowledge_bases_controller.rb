class Api::V1::Accounts::KnowledgeBasesController < Api::V1::Accounts::BaseController
  before_action :fetch_kb, only: %i[show update destroy]

  def index
    render json: Current.account.knowledge_bases.order(:name).map { |kb|
      kb.as_json.merge(
        faq_count: kb.faqs.count,
        site_count: kb.sites.count,
        file_count: kb.files.count,
        inbox_count: kb.inboxes.count
      )
    }
  end

  def show
    render json: @kb.as_json.merge(
      faq_count: @kb.faqs.count,
      site_count: @kb.sites.count,
      file_count: @kb.files.count,
      inbox_ids: @kb.inboxes.pluck(:id)
    )
  end

  def create
    kb = Current.account.knowledge_bases.create!(kb_params)
    render json: kb, status: :created
  end

  def update
    @kb.update!(kb_params)
    render json: @kb
  end

  def destroy
    @kb.destroy!
    head :ok
  end

  private

  def fetch_kb
    @kb = Current.account.knowledge_bases.find(params[:id])
  end

  def kb_params
    params.require(:knowledge_base).permit(:name, :description)
  end
end
