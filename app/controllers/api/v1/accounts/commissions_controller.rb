class Api::V1::Accounts::CommissionsController < Api::V1::Accounts::BaseController
  # GET /api/v1/accounts/:account_id/commissions
  # Params: period (YYYY-MM), professional_id, paid
  def index
    @commissions = Current.account.commissions
                          .includes(:professional, :appointment)
                          .order(created_at: :desc)

    @commissions = @commissions.for_period(params[:period]) if params[:period].present?
    @commissions = @commissions.for_professional(params[:professional_id]) if params[:professional_id].present?
    @commissions = @commissions.where(paid: params[:paid] == 'true') if params[:paid].present?

    render json: @commissions.map { |c| serialize(c) }
  end

  # GET /api/v1/accounts/:account_id/commissions/summary
  # Returns totals per professional for a period
  def summary
    period = params[:period] || Time.zone.now.strftime('%Y-%m')
    scope  = Current.account.commissions.for_period(period)
             .includes(:professional)

    by_professional = scope.group_by(&:professional_id).map do |pid, comms|
      professional = comms.first.professional
      {
        professional_id:   pid,
        professional_name: professional&.name,
        total_amount:      comms.sum(&:amount).to_f,
        paid_amount:       comms.select(&:paid).sum(&:amount).to_f,
        unpaid_amount:     comms.reject(&:paid).sum(&:amount).to_f,
        count:             comms.size,
      }
    end

    render json: {
      period:           period,
      by_professional:  by_professional,
      total_amount:     scope.sum(:amount).to_f,
      paid_amount:      scope.where(paid: true).sum(:amount).to_f,
      unpaid_amount:    scope.where(paid: false).sum(:amount).to_f,
    }
  end

  # PATCH /api/v1/accounts/:account_id/commissions/:id
  def update
    commission = Current.account.commissions.find(params[:id])
    commission.update!(commission_params)
    render json: serialize(commission)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def commission_params
    p = params.permit(:paid, :paid_at)
    p[:paid_at] = Time.current if p[:paid].to_s == 'true' && p[:paid_at].blank?
    p
  end

  def serialize(c)
    {
      id:              c.id,
      professional_id: c.professional_id,
      professional:    c.professional ? { id: c.professional.id, name: c.professional.name } : nil,
      appointment_id:  c.appointment_id,
      percentage:      c.percentage,
      amount:          c.amount,
      paid:            c.paid,
      paid_at:         c.paid_at,
      period:          c.period,
    }
  end
end
