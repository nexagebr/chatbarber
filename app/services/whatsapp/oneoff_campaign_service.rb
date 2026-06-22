class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience(extract_audience_labels)
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'WhatsApp Cloud provider required' if channel.provider != 'whatsapp_cloud'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact, csv_columns: {})
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return
    end

    send_whatsapp_template_message(to: contact.phone_number, contact: contact, csv_columns: csv_columns)
  end

  def process_audience(audience_labels)
    unless audience_labels.empty?
      contact_ids = campaign.account.conversations
                            .tagged_with(audience_labels, any: true)
                            .pluck(:contact_id)
                            .uniq
      contacts = campaign.account.contacts.where(id: contact_ids)
      Rails.logger.info "Processing #{contacts.count} label contacts for campaign #{campaign.id}"
      contacts.each { |contact| process_contact(contact) }
    end

    csv_entries = campaign.audience.select { |a| a['type'] == 'CsvContact' }
    unless csv_entries.empty?
      Rails.logger.info "Processing #{csv_entries.count} CSV contacts for campaign #{campaign.id}"
      csv_entries.each { |entry| process_csv_entry(entry) }
    end

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_csv_entry(entry)
    phone = normalize_phone(entry['phone'])
    unless phone
      Rails.logger.warn "Skipping CSV entry — invalid phone: #{entry['phone'].inspect} (name: #{entry['name'].inspect})"
      return
    end
    contact = find_or_create_contact_by_phone(phone: phone, name: entry['name'])
    return unless contact

    process_contact(contact, csv_columns: entry['columns'] || {})
  rescue StandardError => e
    Rails.logger.error "Failed to process CSV entry #{entry['phone']}: #{e.message}"
  end

  def find_or_create_contact_by_phone(phone:, name: nil)
    contact = campaign.account.contacts.find_by(phone_number: phone)
    return contact if contact

    campaign.account.contacts.create!(
      phone_number: phone,
      name: name.presence || phone,
      account_id: campaign.account_id
    )
  rescue StandardError => e
    Rails.logger.error "Failed to find/create contact for #{phone}: #{e.message}"
    nil
  end

  def normalize_phone(raw)
    return nil if raw.blank?

    digits = raw.to_s.gsub(/\D/, '')
    return nil if digits.length < 8

    # Add BR country code when number has no country code (up to 12 digits covers DDD+9)
    digits = "55#{digits}" if digits.length <= 12 && !digits.start_with?('55')
    "+#{digits}"
  end

  def send_whatsapp_template_message(to:, contact: nil, csv_columns: {})
    personalized_params = contact ? personalize_template_params(campaign.template_params, contact, csv_columns) : campaign.template_params

    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: personalized_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)

    record_campaign_message(contact, name, personalized_params) if contact

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    nil
  end

  def record_campaign_message(contact, template_name, template_params)
    contact_inbox = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) do |ci|
      ci.source_id = contact.phone_number
    end

    conversation = contact_inbox.conversations.order(last_activity_at: :desc).first ||
                   Conversation.create!(
                     account: campaign.account,
                     inbox: inbox,
                     contact: contact,
                     contact_inbox: contact_inbox
                   )

    rendered = render_template_body(template_name, template_params) || "Campanha: #{template_name}"

    # Use insert (no callbacks) to avoid triggering Whatsapp::SendOnWhatsappService again
    # source_id must be set so the WhatsApp frontend shows checkmark instead of clock
    Message.insert({
      account_id: campaign.account_id,
      inbox_id: inbox.id,
      conversation_id: conversation.id,
      message_type: Message.message_types[:outgoing],
      content_type: Message.content_types[:text],
      content: rendered,
      status: Message.statuses[:sent],
      source_id: "campaign_#{campaign.id}_contact_#{contact.id}",
      private: false,
      created_at: Time.current,
      updated_at: Time.current
    })
  rescue StandardError => e
    Rails.logger.error "Failed to record campaign message for #{contact.name}: #{e.message}"
  end

  def render_template_body(template_name, template_params)
    template = channel.message_templates&.find { |t| t['name'] == template_name }
    return nil unless template

    body = template['components']&.find { |c| c['type'] == 'BODY' }
    return nil unless body

    text = body['text'].to_s
    # body vars keyed by variable name or position: {'nome'=>'João'} or {'1'=>'João'}
    body_vars = template_params.dig('processed_params', 'body') || {}
    body_vars.each { |key, value| text = text.gsub("{{#{key}}}", value.to_s) }
    text
  rescue StandardError
    nil
  end

  CONTACT_TOKENS = {
    '{{contact_name}}' => ->(c) { c.name.to_s },
    '{{contact_first_name}}' => ->(c) { c.name.to_s.split(' ', 2).first.to_s },
    '{{contact_phone}}' => ->(c) { c.phone_number.to_s },
    '{{contact_email}}' => ->(c) { c.email.to_s }
  }.freeze

  def personalize_template_params(params, contact, csv_columns = {})
    return params if params.blank?

    token_map = CONTACT_TOKENS.transform_values { |fn| fn.call(contact) }
    csv_columns.each { |col, val| token_map["{{csv:#{col}}}"] = val.to_s }

    deep_replace(params.deep_dup, token_map)
  end

  def deep_replace(obj, token_map)
    case obj
    when Hash
      obj.transform_values { |v| deep_replace(v, token_map) }
    when Array
      obj.map { |v| deep_replace(v, token_map) }
    when String
      token_map.reduce(obj) { |str, (token, value)| str.gsub(token, value) }
    else
      obj
    end
  end
end
