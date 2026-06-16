# frozen_string_literal: true

class KanbanFunnelInbox < ApplicationRecord
  belongs_to :kanban_funnel
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :kanban_funnel_id }
end
