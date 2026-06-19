class Api::V1::Accounts::CashTransactionsController < Api::V1::Accounts::BaseController
  before_action :fetch_transaction, only: [:destroy]

  # GET /api/v1/accounts/:account_id/cash_transactions
  # Params: date (YYYY-MM-DD), from, to, branch_id, transaction_type
  def index
    @transactions = Current.account.cash_transactions
                           .includes(:professional, :appointment, :branch)
                           .order(date: :desc)
    @commissions_by_appt = build_commissions_index(@transactions)

    if params[:date].present?
      d = Date.parse(params[:date]) rescue Date.today
      @transactions = @transactions.on_date(d)
    elsif params[:from].present? && params[:to].present?
      @transactions = @transactions.in_range(params[:from], params[:to])
    end

    @transactions = @transactions.where(branch_id: params[:branch_id]) if params[:branch_id].present?
    @transactions = @transactions.where(transaction_type: params[:transaction_type]) if params[:transaction_type].present?

    render json: @transactions.map { |t| serialize(t, @commissions_by_appt) }
  end

  # GET /api/v1/accounts/:account_id/cash_transactions/summary
  # Returns totals grouped by payment_method + expenses total + net
  def summary
    date  = params[:date].present? ? (Date.parse(params[:date]) rescue Date.today) : Date.today
    scope = Current.account.cash_transactions.on_date(date)
    scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?

    income_rows  = scope.income
    expense_rows = scope.expense

    income_by_method = CashTransaction::PAYMENT_METHODS.each_with_object({}) do |m, h|
      h[m] = income_rows.where(payment_method: m).sum(:amount).to_f
    end
    income_total  = income_rows.sum(:amount).to_f
    expense_total = expense_rows.sum(:amount).to_f

    render json: {
      date:             date,
      income_total:     income_total,
      expense_total:    expense_total,
      net:              income_total - expense_total,
      income_by_method: income_by_method,
      transaction_count: scope.count,
    }
  end

  # POST /api/v1/accounts/:account_id/cash_transactions
  def create
    ActiveRecord::Base.transaction do
      @transaction = Current.account.cash_transactions.create!(transaction_params)
      @commission  = create_commission_if_needed(@transaction)
    end
    render json: serialize(@transaction.reload, { @transaction.appointment_id => @commission }), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /api/v1/accounts/:account_id/cash_transactions/:id
  def destroy
    @transaction.destroy!
    head :no_content
  end

  private

  def fetch_transaction
    @transaction = Current.account.cash_transactions.find(params[:id])
  end

  def transaction_params
    params.permit(:transaction_type, :payment_method, :category, :description,
                  :amount, :date, :professional_id, :appointment_id, :branch_id)
  end

  def create_commission_if_needed(txn)
    return unless txn.transaction_type == 'income'
    return unless txn.professional_id.present?

    professional = Current.account.professionals.find_by(id: txn.professional_id)
    return unless professional&.commission_pct.to_f > 0

    pct    = professional.commission_pct.to_f
    amount = (txn.amount * pct / 100.0).round(2)
    period = txn.date.strftime('%Y-%m')

    Current.account.commissions.create!(
      professional_id: txn.professional_id,
      appointment_id:  txn.appointment_id,
      percentage:      pct,
      amount:          amount,
      period:          period,
      paid:            false
    )
  end

  def build_commissions_index(transactions)
    appt_ids = transactions.filter_map(&:appointment_id)
    return {} if appt_ids.empty?

    Current.account.commissions
           .where(appointment_id: appt_ids)
           .index_by(&:appointment_id)
  end

  def serialize(t, commissions_by_appt = {})
    commission = t.appointment_id ? commissions_by_appt[t.appointment_id] : nil
    {
      id:               t.id,
      transaction_type: t.transaction_type,
      payment_method:   t.payment_method,
      category:         t.category,
      description:      t.description,
      amount:           t.amount,
      date:             t.date,
      branch_id:        t.branch_id,
      appointment_id:   t.appointment_id,
      professional:     t.professional ? { id: t.professional.id, name: t.professional.name } : nil,
      commission:       commission ? { id: commission.id, amount: commission.amount, percentage: commission.percentage, paid: commission.paid } : nil,
    }
  end
end
