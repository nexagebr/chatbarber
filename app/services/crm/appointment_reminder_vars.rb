# Fonte única de variáveis para lembretes de agendamento.
# Reusada pelos dois caminhos de envio: texto livre e template HSM.
#
# Uso — texto livre:
#   vars = Crm::AppointmentReminderVars.new(appointment: appt)
#   vars.render("Olá {{contact_name}}! Seu horário é {{date}} às {{time}} com {{professional}}.")
#
# Uso — template posicional ({{1}}, {{2}}, ...):
#   vars.body_params(['contact_name', 'date', 'time'])
#   # => { '1' => 'João', '2' => '17/06', '3' => '14:00' }
class Crm::AppointmentReminderVars
  SUPPORTED_VARS = %w[contact_name date time professional service].freeze

  def initialize(appointment:)
    @appointment = appointment
  end

  # Retorna hash com todos os valores disponíveis (chave = nome da variável).
  def to_h
    {
      'contact_name' => @appointment.contact&.name.to_s,
      'date'         => format_date,
      'time'         => format_time,
      'professional' => @appointment.professional&.name.to_s,
      'service'      => @appointment.services.first&.name.to_s
    }
  end

  # Substitui tokens {{nome}} no template de texto livre.
  # Tokens desconhecidos são silenciosamente removidos.
  def render(template_string)
    result = template_string.dup
    to_h.each { |key, value| result.gsub!("{{#{key}}}", value) }
    # remove qualquer token desconhecido que reste
    result.gsub!(/\{\{[^}]+\}\}/, '')
    result
  end

  # Monta o hash posicional { '1' => valor, '2' => valor, ... } para
  # processed_params.body de um template HSM.
  # order_array: array de nomes de variáveis na ordem dos slots do template,
  #              ex: ['contact_name', 'date', 'time']
  def body_params(order_array)
    values = to_h
    order_array.each_with_index.each_with_object({}) do |(var_name, idx), hash|
      hash[(idx + 1).to_s] = values.fetch(var_name, '')
    end
  end

  private

  def format_date
    return '' if @appointment.scheduled_at.blank?

    @appointment.scheduled_at.in_time_zone(Time.zone).strftime('%d/%m/%Y')
  end

  def format_time
    return '' if @appointment.scheduled_at.blank?

    @appointment.scheduled_at.in_time_zone(Time.zone).strftime('%H:%M')
  end
end
