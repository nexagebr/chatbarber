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

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
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
