class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: personalize_for_contact(template_params),
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def send_session_message
    message_id = channel.send_message(message.conversation.contact_inbox.source_id, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end

  def personalize_for_contact(params)
    return params if params.blank?

    contact = message.conversation.contact
    return params unless contact

    token_map = {
      '{{contact_name}}' => contact.name.to_s,
      '{{contact_first_name}}' => contact.name.to_s.split(' ', 2).first.to_s,
      '{{contact_phone}}' => contact.phone_number.to_s,
      '{{contact_email}}' => contact.email.to_s
    }
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
