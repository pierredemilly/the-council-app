class AddPacingToAppConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :app_configs, :continue_grace_ms, :integer, null: false, default: 2000
    add_column :app_configs, :max_unprompted_segments, :integer, null: false, default: 2
    change_column_default :app_configs, :yield_grace_ms, from: 2500, to: 5000
  end
end
