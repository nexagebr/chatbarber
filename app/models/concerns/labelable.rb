module Labelable
  extend ActiveSupport::Concern

  included do
    acts_as_taggable_on :labels
  end

  def update_labels(labels = nil)
    update!(label_list: labels)
  end

  def add_labels(new_labels = nil)
    return if new_labels.blank?

    new_labels = Array(new_labels) # Make sure new_labels is an array
    combined_labels = labels + new_labels
    update!(label_list: combined_labels)
    
    # Trigger kanban stage update if this is a Contact
    update_kanban_stage_from_labels(new_labels) if is_a?(Contact)
  end

  private

  def update_kanban_stage_from_labels(new_labels)
    return unless respond_to?(:account)

    new_labels.each do |label|
      # Find kanban stage linked to this label
      kanban_stage = account.kanban_stages.find_by(label_id: label.id)
      
      next unless kanban_stage

      # Update contact's kanban stage
      additional_attrs = additional_attributes || {}
      additional_attrs['kanban_stage_id'] = kanban_stage.id
      
      update_column(:additional_attributes, additional_attrs)
      
      Rails.logger.info "Contact #{id} moved to kanban stage '#{kanban_stage.name}' based on label '#{label.title}'"
      
      # Only move to the first matching stage
      break
    end
  end
end
