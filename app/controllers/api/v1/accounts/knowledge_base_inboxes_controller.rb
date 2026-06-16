class Api::V1::Accounts::KnowledgeBaseInboxesController < Api::V1::Accounts::BaseController
  before_action :fetch_kb

  def show
    render json: @kb.inboxes.pluck(:id)
  end

  def update
    inbox_ids = params[:inbox_ids] || []
    @kb.knowledge_base_inboxes.destroy_all
    inbox_ids.each do |id|
      @kb.knowledge_base_inboxes.create!(inbox_id: id)
    end
    render json: @kb.inboxes.pluck(:id)
  end

  private

  def fetch_kb
    @kb = Current.account.knowledge_bases.find(params[:knowledge_basis_id])
  end
end
