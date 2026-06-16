class AddColorToProfessionals < ActiveRecord::Migration[7.0]
  def change
    add_column :professionals, :color, :string
  end
end
