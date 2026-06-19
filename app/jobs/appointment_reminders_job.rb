# Job que envia lembretes automáticos de agendamento por WhatsApp.
#
# Executado a cada 5 min via TriggerScheduledItemsJob (que já está registrado
# no config/schedule.yml). Não precisa de entrada própria no schedule.yml.
#
# Lógica híbrida:
#   - Se conversation.can_reply? (dentro da janela de 24h ou provedor não-oficial):
#       envia texto livre via Messages::MessageBuilder.
#   - Se !conversation.can_reply? (fora da janela, ex: WhatsApp Cloud API oficial):
#       envia template HSM se appointment_reminder_template estiver configurado;
#       caso contrário, skipa (sem marcar como enviado — tenta de novo no próximo ciclo).
class AppointmentRemindersJob < ApplicationJob
  queue_as :scheduled_jobs

  DEFAULT_TEXT = "Olá {{contact_name}}! Passando para lembrar do seu horário dia {{date}} às {{time}} com {{professional}}. Posso confirmar? 💈"

  def perform
    Account.where("settings->>'appointment_reminder_enabled' = 'true'").find_each do |account|
      process_account(account)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  private

  def process_account(account)
    hours = [(account.appointment_reminder_hours_before.to_i.presence || 2), 1].max
    window_start = Time.current
    window_end   = Time.current + hours.hours

    account.appointments
           .pending_reminder
           .where(scheduled_at: window_start..window_end)
           .includes(:contact, :professional, :services, conversation: :inbox)
           .find_each do |appointment|
      process_appointment(account, appointment)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  def process_appointment(account, appointment)
    conversation = resolve_conversation(appointment)

    unless conversation
      # Sem conversa: marca como "processado" para não tentar infinitamente.
      appointment.update_columns(reminder_sent_at: Time.current)
      Rails.logger.info("[AppointmentRemindersJob] appointment ##{appointment.id}: sem conversa, pulando envio")
      return
    end

    vars = Crm::AppointmentReminderVars.new(appointment: appointment)

    if conversation.can_reply?
      send_free_text(account, appointment, conversation, vars)
    else
      send_template_or_skip(account, appointment, conversation, vars)
    end
  end

  def resolve_conversation(appointment)
    return appointment.conversation if appointment.conversation_id.present? && appointment.conversation

    # Fallback: conversa mais recente do contato
    appointment.contact&.conversations&.order(last_activity_at: :desc)&.first
  end

  def send_free_text(account, appointment, conversation, vars)
    template_string = account.appointment_reminder_message.presence || DEFAULT_TEXT
    content = vars.render(template_string)

    Messages::MessageBuilder.new(nil, conversation, {
      message_type: 'outgoing',
      content: content,
      private: false
    }).perform

    appointment.update_columns(reminder_sent_at: Time.current)
    Rails.logger.info("[AppointmentRemindersJob] appointment ##{appointment.id}: lembrete texto livre enviado")
  end

  def send_template_or_skip(account, appointment, conversation, vars)
    cfg = account.appointment_reminder_template

    unless cfg.present? && cfg['name'].present?
      Rails.logger.info("[AppointmentRemindersJob] appointment ##{appointment.id}: fora da janela de 24h e sem template configurado, pulando")
      return
    end

    body_params_order = cfg['body_params'] || []
    processed_params  = { body: vars.body_params(body_params_order) }
    processed_params[:header] = cfg['header_params'] if cfg['header_params'].present?

    template_params = {
      name:             cfg['name'],
      language:         cfg['language'] || 'pt_BR',
      processed_params: processed_params
    }
    template_params[:namespace] = cfg['namespace'] if cfg['namespace'].present?

    # Fallback de conteúdo legível (caso o canal não seja WhatsApp / para o histórico)
    fallback_text = vars.render(account.appointment_reminder_message.presence || DEFAULT_TEXT)

    Messages::MessageBuilder.new(nil, conversation, {
      message_type:    'outgoing',
      content:         fallback_text,
      template_params: template_params,
      private:         false
    }).perform

    appointment.update_columns(reminder_sent_at: Time.current)
    Rails.logger.info("[AppointmentRemindersJob] appointment ##{appointment.id}: lembrete template '#{cfg['name']}' enviado")
  end
end
