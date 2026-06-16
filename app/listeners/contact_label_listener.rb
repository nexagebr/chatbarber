# frozen_string_literal: true

class ContactLabelListener < BaseListener
  def label_added(event)
    contact = event.data[:contact]
    label = event.data[:label]
    
    update_kanban_stage_for_label(contact, label)
  end

  def label_removed(event)
    # Optionally handle label removal if needed
    # For now, we only move forward when labels are added
  end

  private

  def update_kanban_stage_for_label(contact, label)
    # Find kanban stage linked to this label
    kanban_stage = contact.account.kanban_stages.find_by(label_id: label.id)
    
    return unless kanban_stage

    # Update contact's kanban stage
    additional_attrs = contact.additional_attributes || {}
    additional_attrs['kanban_stage_id'] = kanban_stage.id
    
    contact.update(additional_attributes: additional_attrs)
    
    Rails.logger.info "Contact #{contact.id} moved to kanban stage '#{kanban_stage.name}' based on label '#{label.title}'"
  end
end
