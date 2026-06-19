# Job que envia mensagens de retenção automáticas:
#   - Win-back: cliente sem visita (agendamento `completed`) há X dias
#   - Aniversário: cliente aniversariante hoje (birthday em custom_attributes)
#
# Executado a cada 5 min via TriggerScheduledItemsJob (piggyback).
# Lógica híbrida de envio idêntica ao AppointmentRemindersJob:
#   - can_reply? true  → texto livre via Messages::MessageBuilder
#   - can_reply? false → template HSM se configurado, caso contrário skipa
#
# Idempotência:
#   - Win-back:    contact.last_winback_sent_at (cooldown = winback_days atrás)
#   - Aniversário: contact.last_birthday_greeting_at (uma vez por ano)
class RetentionMessagesJob < ApplicationJob
  queue_as :scheduled_jobs

  DEFAULT_WINBACK_MESSAGE  = 'Olá {{contact_name}}! Sentimos sua falta 😊 Faz {{days_since}} dias desde o seu último {{last_service}}. Que tal marcar um horário? 💈'
  DEFAULT_BIRTHDAY_MESSAGE = 'Feliz aniversário, {{contact_name}}! 🎂🎉 Que seu dia seja incrível! A equipe da barbearia tem um mimo especial esperando por você. Agende já!'

  def perform
    Account.where(
      "settings->>'retention_winback_enabled' = 'true' OR settings->>'retention_birthday_enabled' = 'true'"
    ).find_each do |account|
      process_account(account)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  private

  # ─────────────────────────────────────────────────────────────
  # Account-level dispatchers
  # ─────────────────────────────────────────────────────────────

  def process_account(account)
    process_winback(account)  if account.retention_winback_enabled
    process_birthday(account) if account.retention_birthday_enabled
  end

  def process_winback(account)
    days   = [(account.retention_winback_days.to_i.presence || 60), 7].max
    cutoff = days.days.ago

    # Contacts whose most recent completed appointment is older than the cutoff
    lapsed_ids = account.appointments
                        .completed
                        .group(:contact_id)
                        .having('MAX(scheduled_at) < ?', cutoff)
                        .pluck(:contact_id)
                        .compact

    return if lapsed_ids.empty?

    # Skip contacts we already messaged recently (cooldown = same window)
    targets = account.contacts
                     .where(id: lapsed_ids)
                     .where('last_winback_sent_at IS NULL OR last_winback_sent_at < ?', cutoff)
                     .includes(:conversations)

    targets.find_each do |contact|
      process_winback_contact(account, contact, cutoff)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  def process_birthday(account)
    today = Time.zone.today
    # Match contacts whose birthday month-day equals today's month-day
    mmdd  = today.strftime('-%m-%d')

    targets = account.contacts
                     .where("custom_attributes->>'birthday' LIKE ?", "%#{mmdd}")
                     .where(
                       'last_birthday_greeting_at IS NULL OR ' \
                       'EXTRACT(YEAR FROM last_birthday_greeting_at) < ?',
                       today.year
                     )
                     .includes(:conversations)

    targets.find_each do |contact|
      process_birthday_contact(account, contact)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Contact-level senders
  # ─────────────────────────────────────────────────────────────

  def process_winback_contact(account, contact, _cutoff)
    last_appt = contact.appointments.completed.order(scheduled_at: :desc).first
    vars      = Crm::RetentionVars.new(contact: contact, last_appointment: last_appt)

    sent = send_message(account, contact, vars, kind: :winback)
    contact.update_columns(last_winback_sent_at: Time.current) if sent
  end

  def process_birthday_contact(account, contact)
    vars = Crm::RetentionVars.new(contact: contact)

    sent = send_message(account, contact, vars, kind: :birthday)
    contact.update_columns(last_birthday_greeting_at: Time.current) if sent
  end

  # ─────────────────────────────────────────────────────────────
  # Hybrid send (text-free or template)
  # ─────────────────────────────────────────────────────────────

  def send_message(account, contact, vars, kind:)
    conversation = resolve_or_create_conversation(account, contact)

    unless conversation
      Rails.logger.info("[RetentionMessagesJob] contact ##{contact.id} (#{kind}): sem conversa e sem inbox de reativação configurado — pulando")
      return false
    end

    if conversation.can_reply?
      send_free_text(account, conversation, vars, kind: kind)
    else
      send_template_or_skip(account, conversation, vars, kind: kind)
    end
  end

  def send_free_text(account, conversation, vars, kind:)
    content = vars.render(message_for(account, kind))

    Messages::MessageBuilder.new(nil, conversation, {
      message_type: 'outgoing',
      content:      content,
      private:      false
    }).perform

    Rails.logger.info("[RetentionMessagesJob] #{kind} texto livre enviado (conv ##{conversation.id})")
    true
  end

  def send_template_or_skip(account, conversation, vars, kind:)
    cfg = template_for(account, kind)

    unless cfg.present? && cfg['name'].present?
      Rails.logger.info("[RetentionMessagesJob] #{kind}: fora da janela de 24h e sem template configurado — pulando")
      return false
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

    fallback_text = vars.render(message_for(account, kind))

    Messages::MessageBuilder.new(nil, conversation, {
      message_type:    'outgoing',
      content:         fallback_text,
      template_params: template_params,
      private:         false
    }).perform

    Rails.logger.info("[RetentionMessagesJob] #{kind} template '#{cfg['name']}' enviado (conv ##{conversation.id})")
    true
  end

  # ─────────────────────────────────────────────────────────────
  # Conversation resolution / outreach creation
  # ─────────────────────────────────────────────────────────────

  def resolve_or_create_conversation(account, contact)
    # 1. Use most recent existing conversation
    conv = contact.conversations.order(last_activity_at: :desc).first
    return conv if conv

    # 2. Outreach: create ContactInbox + Conversation on the configured retention inbox
    inbox_id = account.retention_inbox_id.to_i
    return nil if inbox_id.zero?

    inbox = account.inboxes.find_by(id: inbox_id)
    return nil unless inbox
    return nil if contact.phone_number.blank? && !%w[Channel::Api Channel::WebWidget].include?(inbox.channel_type)

    begin
      contact_inbox = ContactInboxBuilder.new(
        contact:  contact,
        inbox:    inbox
      ).perform

      return nil unless contact_inbox

      Conversation.create!(
        account_id:        account.id,
        inbox_id:          contact_inbox.inbox_id,
        contact_id:        contact_inbox.contact_id,
        contact_inbox_id:  contact_inbox.id,
        additional_attributes: { initiated_by: 'retention_automation' }
      )
    rescue StandardError => e
      Rails.logger.error("[RetentionMessagesJob] não foi possível criar conversa para contact ##{contact.id}: #{e.message}")
      nil
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Helpers
  # ─────────────────────────────────────────────────────────────

  def message_for(account, kind)
    case kind
    when :winback
      account.retention_winback_message.presence || DEFAULT_WINBACK_MESSAGE
    when :birthday
      account.retention_birthday_message.presence || DEFAULT_BIRTHDAY_MESSAGE
    end
  end

  def template_for(account, kind)
    case kind
    when :winback  then account.retention_winback_template
    when :birthday then account.retention_birthday_template
    end
  end
end
