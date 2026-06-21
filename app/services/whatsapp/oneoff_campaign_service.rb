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

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return
    end

    send_whatsapp_template_message(to: contact.phone_number, contact: contact)
  end

  def process_audience(audience_labels)
    contact_ids = campaign.account.conversations
                          .tagged_with(audience_labels, any: true)
                          .pluck(:contact_id)
                          .uniq
    contacts = campaign.account.contacts.where(id: contact_ids)
    Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"

    contacts.each { |contact| process_contact(contact) }

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def send_whatsapp_template_message(to:, contact: nil)
    personalized_params = contact ? personalize_template_params(campaign.template_params, contact) : campaign.template_params

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

    record_campaign_message(contact, name, personalized_params, processed_parameters) if contact

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    nil
  end

  def record_campaign_message(contact, template_name, template_params, processed_parameters)
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

    rendered = render_template_body(template_name, processed_parameters) || "Campanha: #{template_name}"

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

  def render_template_body(template_name, processed_parameters)
    template = channel.message_templates&.find { |t| t['name'] == template_name }
    return nil unless template

    body = template['components']&.find { |c| c['type'] == 'BODY' }
    return nil unless body

    text = body['text'].to_s

    # processed_parameters is [{type:'body', parameters:[{type:'text',text:'val'}]}, ...]
    body_component = processed_parameters&.find { |c| c[:type] == 'body' || c['type'] == 'body' }
    body_params = body_component&.dig(:parameters) || body_component&.dig('parameters') || []

    body_params.each_with_index do |param, idx|
      value = param[:text] || param['text'] || ''
      text = text.gsub("{{#{idx + 1}}}", value.to_s)
    end
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

  def personalize_template_params(params, contact)
    return params if params.blank?

    token_map = CONTACT_TOKENS.transform_values { |fn| fn.call(contact) }

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
