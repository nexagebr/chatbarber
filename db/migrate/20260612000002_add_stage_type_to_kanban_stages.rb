# frozen_string_literal: true

class AddStageTypeToKanbanStages < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_stages, :stage_type, :integer, default: 0, null: false
    # 0 = regular, 1 = won, 2 = lost
  end
end
