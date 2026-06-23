class Whatsapp::CreateTemplateService
  def initialize(channel:, params:)
    @channel = channel
    @params = params
  end

  def call
    request_body = build_request_body
    Rails.logger.info "[CreateTemplateService] Sending to Meta: #{request_body.to_json}"

    response = HTTParty.post(
      "#{business_account_path}/message_templates",
      headers: api_headers,
      body: request_body.to_json
    )

    Rails.logger.info "[CreateTemplateService] Meta response #{response.code}: #{response.body}"

    if response.success?
      template = response.parsed_response
      sync_templates_later
      { success: true, template: template }
    else
      parsed = response.parsed_response
      error_msg = parsed&.dig('error', 'message')
      error_details = parsed&.dig('error', 'error_user_msg') || parsed&.dig('error', 'error_subcode')
      full_error = [error_msg, error_details].compact.join(' — ')
      { success: false, error: full_error.presence || "Meta API error #{response.code}" }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def build_request_body
    {
      name: @params[:name].to_s.downcase.gsub(/\s+/, '_'),
      category: @params[:category] || 'MARKETING',
      language: @params[:language] || 'pt_BR',
      components: normalize_components(@params[:components] || [])
    }
  end

  def normalize_components(components)
    components.map do |comp|
      next comp unless comp['type'] == 'BODY'

      vars = comp['text'].to_s.scan(/\{\{([^}]+)\}\}/).map(&:first).uniq
      next comp if vars.empty? || comp['example'].present?

      comp.merge('example' => { 'body_text' => [vars.each_with_index.map { |_, i| "exemplo#{i + 1}" }] })
    end
  end

  def sync_templates_later
    Channels::Whatsapp::TemplatesSyncJob.perform_later(@channel)
  end

  def api_headers
    { 'Authorization' => "Bearer #{@channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def business_account_path
    "https://graph.facebook.com/v18.0/#{@channel.provider_config['business_account_id']}"
  end
end
