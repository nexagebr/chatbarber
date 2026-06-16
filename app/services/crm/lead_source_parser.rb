module Crm
  class LeadSourceParser
    UTM_PARAMS  = %w[utm_source utm_medium utm_campaign utm_term utm_content].freeze
    TRACKING_PARAMS = %w[gclid fbclid ttclid msclkid].freeze
    RELEVANT_PARAMS = (UTM_PARAMS + TRACKING_PARAMS).freeze

    # Parse UTM / gclid / fbclid from a URL string.
    # Returns {} when the URL has no relevant params or is invalid.
    def self.from_url(url_string)
      return {} if url_string.blank?

      uri    = URI.parse(url_string.to_s)
      query  = Rack::Utils.parse_nested_query(uri.query.to_s)
      result = {}

      UTM_PARAMS.each do |key|
        short = key.delete_prefix('utm_').to_sym
        result[short] = query[key] if query[key].present?
      end
      TRACKING_PARAMS.each do |key|
        result[key.to_sym] = query[key] if query[key].present?
      end

      return {} if result.empty?

      result.merge(
        channel:     'website',
        referer_url: url_string.to_s,
        captured_at: Time.current.iso8601
      )
    rescue URI::InvalidURIError, ArgumentError
      {}
    end

    # Parse a WhatsApp Ads Click-to-WhatsApp referral payload.
    # Also extracts UTM/gclid from source_url if present.
    # referral_hash: Hash with symbolized or string keys from @processed_params[:messages].first[:referral]
    def self.from_whatsapp_referral(referral_hash)
      return {} if referral_hash.blank?

      ref = referral_hash.with_indifferent_access

      result = {
        channel:     'whatsapp_ad',
        referer_url: ref[:source_url].presence,
        ad: {
          source_id:   ref[:source_id].presence,
          source_type: ref[:source_type].presence,
          headline:    ref[:headline].presence,
          body:        ref[:body].presence,
          media_type:  ref[:media_type].presence,
          ctwa_clid:   ref[:ctwa_clid].presence
        }.compact,
        captured_at: Time.current.iso8601
      }.compact

      # Also try to pull UTM/gclid from the source_url
      if ref[:source_url].present?
        url_attrs = from_url(ref[:source_url])
        utm_keys = %i[source medium campaign term content gclid fbclid ttclid msclkid]
        url_attrs.slice(*utm_keys).each { |k, v| result[k] = v }
      end

      result
    end
  end
end
