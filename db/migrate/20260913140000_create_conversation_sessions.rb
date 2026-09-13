class CreateConversationSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_sessions, id: :uuid do |t|
      t.string :client_token_digest, null: false
      t.string :status, null: false, default: "created"
      t.string :client_mode, null: false, default: "browser"
      t.jsonb :config_snapshot, null: false, default: {}
      t.integer :version, null: false, default: 0
      t.integer :next_seq, null: false, default: 1
      t.string :language
      t.datetime :started_at, null: false
      t.datetime :first_utterance_at
      t.datetime :last_seen_at, null: false
      t.datetime :last_activity_at, null: false
      t.datetime :finalized_at
      t.string :finalize_reason
      t.jsonb :metrics, null: false, default: {}

      t.timestamps
    end

    add_index :conversation_sessions, [ :status, :last_seen_at ]

    create_table :conversation_events do |t|
      t.references :conversation_session, type: :uuid, null: false, foreign_key: true
      t.integer :seq, null: false
      t.string :kind, null: false
      t.string :speaker
      t.text :text, null: false
      t.boolean :interrupted, null: false, default: false
      t.integer :spoken_ms
      t.jsonb :latency, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :conversation_events, [ :conversation_session_id, :seq ], unique: true

    create_table :session_turns, id: :uuid do |t|
      t.references :conversation_session, type: :uuid, null: false, foreign_key: true
      t.uuid :generation_id, null: false
      t.integer :version, null: false
      t.integer :position, null: false
      t.string :speaker, null: false
      t.text :text, null: false
      t.string :next_action
      t.string :status, null: false, default: "pending"
      t.integer :duration_ms

      t.timestamps
    end

    add_index :session_turns, [ :conversation_session_id, :generation_id, :position ], unique: true, name: "index_session_turns_on_generation_position"
    add_index :session_turns, [ :conversation_session_id, :status ]
  end
end
