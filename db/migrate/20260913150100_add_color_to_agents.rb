class AddColorToAgents < ActiveRecord::Migration[8.0]
  PALETTE = %w[#f59e0b #38bdf8 #f472b6].freeze

  def up
    add_column :agents, :color, :string
    PALETTE.each_with_index do |color, index|
      execute "UPDATE agents SET color = '#{color}' WHERE position = #{index + 1}"
    end
  end

  def down
    remove_column :agents, :color
  end
end
