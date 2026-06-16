class AddShowUnassignedToKanbanFunnels < ActiveRecord::Migration[7.0]
  def change
    add_column :kanban_funnels, :show_unassigned, :boolean, default: true, null: false
  end
end
