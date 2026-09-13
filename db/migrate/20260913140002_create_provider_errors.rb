class CreateProviderErrors < ActiveRecord::Migration[8.0]
  def change
    create_table :provider_errors do |t|
      t.references :conversation_session, type: :uuid, foreign_key: true
      t.string :stage, null: false
      t.string :provider, null: false
      t.integer :attempt, null: false, default: 1
      t.boolean :recoverable, null: false, default: true
      t.string :message, null: false

      t.timestamps
    end

    add_index :provider_errors, [ :stage, :created_at ]
  end
end
