class Api::V1::Accounts::ProductsController < Api::V1::Accounts::BaseController
  before_action :fetch_product, only: [:show, :update, :destroy]

  def index
    @products = Current.account.products.order(:name)
    @products = @products.where('name ILIKE ? OR category ILIKE ? OR sku ILIKE ?',
                                "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    render json: @products
  end

  def show
    render json: @product
  end

  def create
    @product = Current.account.products.create!(product_params)
    render json: @product, status: :created
  end

  def update
    @product.update!(product_params)
    render json: @product
  end

  def destroy
    @product.destroy!
    head :no_content
  end

  private

  def fetch_product
    @product = Current.account.products.find(params[:id])
  end

  def product_params
    params.permit(:name, :description, :price, :cost, :stock, :category, :sku, :external_id, :active, :tipo, :duracao)
  end
end
