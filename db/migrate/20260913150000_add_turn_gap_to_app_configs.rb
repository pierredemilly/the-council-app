class AddTurnGapToAppConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :app_configs, :turn_gap_ms, :integer, null: false, default: 700
  end
end
