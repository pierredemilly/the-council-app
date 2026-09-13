class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.integer :position, null: false
      t.string :name, null: false
      t.text :personality, null: false, default: ""
      t.string :voice_id
      t.string :voice_name

      t.timestamps
    end

    add_index :agents, :position, unique: true
    add_index :agents, "lower(name)", unique: true, name: "index_agents_on_lower_name"
  end
end
