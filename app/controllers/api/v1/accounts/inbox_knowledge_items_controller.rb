class Api::V1::Accounts::InboxKnowledgeItemsController < Api::V1::Accounts::BaseController
  before_action :fetch_item, only: %i[update destroy]

  def index
    items = Current.account.inbox_knowledge_items.for_inbox(params[:inbox_id]).ordered
    items = items.search(params[:search]) if params[:search].present?
    render json: items
  end

  def create
    item = Current.account.inbox_knowledge_items.create!(item_params)
    render json: item, status: :created
  end

  def update
    @item.update!(item_params)
    render json: @item
  end

  def destroy
    @item.destroy!
    head :ok
  end

  private

  def fetch_item
    @item = Current.account.inbox_knowledge_items.find(params[:id])
  end

  def item_params
    params.require(:inbox_knowledge_item).permit(:inbox_id, :category, :question, :answer, :position)
  end
end
