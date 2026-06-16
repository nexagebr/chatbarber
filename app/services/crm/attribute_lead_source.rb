module Crm
  class AttributeLeadSource
    pattr_initialize [:conversation!, :lead_source!, :force_update]

    def initialize(conversation:, lead_source:, force_update: false)
      @conversation  = conversation
      @lead_source   = lead_source.with_indifferent_access
      @force_update  = force_update
    end

    def perform
      return if @lead_source.blank?

      set_on_conversation
      set_first_touch_on_contact
    end

    private

    def set_on_conversation
      attrs  = @conversation.additional_attributes.with_indifferent_access
      existing = attrs[:lead_source].presence

      # Automatic capture: only write if no lead_source exists yet.
      # Manual (force_update): always overwrite.
      return if existing.present? && !@force_update

      attrs[:lead_source] = @lead_source
      @conversation.update_columns(additional_attributes: attrs)
    end

    def set_first_touch_on_contact
      contact = @conversation.contact
      return unless contact

      contact_attrs    = contact.additional_attributes.with_indifferent_access
      existing_contact = contact_attrs[:lead_source].presence

      # Only write if contact has no lead_source yet (first-touch attribution)
      return if existing_contact.present?

      contact_attrs[:lead_source] = @lead_source
      contact.update_columns(additional_attributes: contact_attrs)
    end
  end
end
