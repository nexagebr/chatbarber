class Whatsapp::CreateTemplateService
  def initialize(channel:, params:)
    @channel = channel
    @params = params
  end

  def call
    response = HTTParty.post(
      "#{business_account_path}/message_templates",
      headers: api_headers,
      body: build_request_body.to_json
    )

    if response.success?
      template = response.parsed_response
      sync_templates_later
      { success: true, template: template }
    else
      error = response.parsed_response&.dig('error', 'message') || "Meta API error #{response.code}"
      { success: false, error: error }
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
      components: @params[:components] || []
    }
  end

  def sync_templates_later
    Channels::Whatsapp::TemplatesSyncJob.perform_later(@channel)
  end

  def api_headers
    { 'Authorization' => "Bearer #{@channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def business_account_path
    "https://graph.facebook.com/v14.0/#{@channel.provider_config['business_account_id']}"
  end
end
