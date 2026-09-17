class AddBiographyToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :biography, :text, null: false, default: ""
  end
end
