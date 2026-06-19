# Fonte única de variáveis para mensagens de retenção (win-back e aniversário).
# Reusa a mesma interface de AppointmentReminderVars para compatibilidade com
# o mapeamento de slots do frontend.
#
# Uso — win-back:
#   vars = Crm::RetentionVars.new(contact: c, last_appointment: a)
#   vars.render("Oi {{contact_name}}, faz {{days_since}} dias desde {{last_service}}!")
#
# Uso — aniversário (last_appointment pode ser nil):
#   vars = Crm::RetentionVars.new(contact: c)
#   vars.render("Feliz aniversário, {{contact_name}}! 🎂")
#
# Uso — template posicional:
#   vars.body_params(['contact_name', 'days_since'])
#   # => { '1' => 'João', '2' => '65' }
class Crm::RetentionVars
  SUPPORTED_VARS = %w[contact_name last_service last_professional days_since].freeze

  def initialize(contact:, last_appointment: nil)
    @contact          = contact
    @last_appointment = last_appointment
  end

  # Retorna hash com todos os valores disponíveis (chave = nome da variável).
  def to_h
    {
      'contact_name'      => @contact.name.to_s,
      'last_service'      => @last_appointment&.services&.first&.name.to_s,
      'last_professional' => @last_appointment&.professional&.name.to_s,
      'days_since'        => days_since_last_visit.to_s
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
  #              ex: ['contact_name', 'days_since']
  def body_params(order_array)
    values = to_h
    order_array.each_with_index.each_with_object({}) do |(var_name, idx), hash|
      hash[(idx + 1).to_s] = values.fetch(var_name, '')
    end
  end

  private

  def days_since_last_visit
    return '' if @last_appointment&.scheduled_at.blank?

    (Time.zone.today - @last_appointment.scheduled_at.to_date).to_i
  end
end
