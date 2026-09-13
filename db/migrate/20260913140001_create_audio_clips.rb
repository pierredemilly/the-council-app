class CreateAudioClips < ActiveRecord::Migration[8.0]
  def change
    create_table :audio_clips, id: :uuid do |t|
      t.references :conversation_session, type: :uuid, null: false, foreign_key: true
      t.references :session_turn, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :mime, null: false
      t.binary :bytes, null: false
      t.integer :duration_ms
      t.jsonb :timings
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :audio_clips, :expires_at
  end
end
