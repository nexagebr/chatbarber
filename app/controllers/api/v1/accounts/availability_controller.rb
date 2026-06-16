class Api::V1::Accounts::AvailabilityController < Api::V1::Accounts::BaseController
  # GET /availability?date=2026-06-14&professional_ids[]=1&professional_ids[]=2&branch_id=1
  def index
    date       = params[:date]
    prof_ids   = Array(params[:professional_ids]).map(&:to_i)
    branch_id  = params[:branch_id].presence&.to_i
    day_of_week = Date.parse(date).wday

    # Holiday check per branch
    holiday_map = {}
    if branch_id
      h = Holiday.find_by(branch_id: branch_id, date: date)
      holiday_map[branch_id] = h if h
    else
      # Find holidays for any branch the professionals belong to
      branch_ids = BranchProfessional.where(professional_id: prof_ids).pluck(:branch_id).uniq
      Holiday.where(branch_id: branch_ids, date: date).each { |h| holiday_map[h.branch_id] = h }
    end

    # Branch schedule for the day
    branch_schedule = nil
    if branch_id
      branch_schedule = BranchSchedule.find_by(branch_id: branch_id, day_of_week: day_of_week)
    end

    professionals = {}
    prof_ids.each do |pid|
      prof = Current.account.professionals.find_by(id: pid)
      next unless prof

      # Determine applicable holiday
      if branch_id
        holiday = holiday_map[branch_id]
      else
        prof_branch_ids = BranchProfessional.where(professional_id: pid).pluck(:branch_id)
        holiday = prof_branch_ids.filter_map { |bid| holiday_map[bid] }.first
      end

      schedule     = prof.professional_schedules.find_by(day_of_week: day_of_week)
      breaks       = prof.professional_breaks.where(day_of_week: day_of_week)
      blocked      = prof.professional_blocked_dates.where(date: date)

      full_day_block = blocked.find { |b| b.start_time.blank? || b.end_time.blank? }
      slot_blocks    = blocked.reject { |b| b.start_time.blank? || b.end_time.blank? }

      is_holiday    = holiday.present?
      is_blocked    = full_day_block.present? || is_holiday
      is_working    = schedule ? schedule.active : day_of_week.between?(1, 5)
      start_time    = fmt_time(schedule&.start_time) || '09:00'
      end_time      = fmt_time(schedule&.end_time)   || '18:00'

      blocked_reason = if is_holiday
        "Feriado: #{holiday.name}"
      elsif full_day_block
        full_day_block.reason.presence || 'Profissional bloqueado nesta data'
      end

      professionals[pid] = {
        is_blocked:     is_blocked,
        is_holiday:     is_holiday,
        blocked_reason: blocked_reason,
        is_working_day: is_working,
        start_time:     start_time,
        end_time:       end_time,
        breaks: breaks.map { |b| { id: b.id, start_time: fmt_time(b.start_time), end_time: fmt_time(b.end_time), label: b.label } },
        blocked_slots: slot_blocks.map { |b| { start_time: fmt_time(b.start_time), end_time: fmt_time(b.end_time), reason: b.reason } },
      }
    end

    render json: {
      professionals: professionals,
      branch_schedule: branch_schedule ? {
        active:     branch_schedule.active,
        start_time: fmt_time(branch_schedule.start_time),
        end_time:   fmt_time(branch_schedule.end_time),
      } : nil,
    }
  end

  private

  def fmt_time(val)
    return nil if val.nil?
    val.respond_to?(:strftime) ? val.strftime('%H:%M') : val.to_s[0..4]
  end
end
