# Session-scoped cache of synthesized speech; purged on finalize and by expiry, never kept.
# == Schema Information
#
# Table name: audio_clips
#
#  id                      :uuid             not null, primary key
#  bytes                   :binary           not null
#  duration_ms             :integer
#  expires_at              :datetime         not null
#  mime                    :string           not null
#  timings                 :jsonb
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  conversation_session_id :uuid             not null
#  session_turn_id         :uuid             not null
#
# Indexes
#
#  index_audio_clips_on_conversation_session_id  (conversation_session_id)
#  index_audio_clips_on_expires_at               (expires_at)
#  index_audio_clips_on_session_turn_id          (session_turn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_session_id => conversation_sessions.id)
#  fk_rails_...  (session_turn_id => session_turns.id)
#
class AudioClip < ApplicationRecord
  TTL = 1.hour

  belongs_to :conversation_session
  belongs_to :session_turn

  validates :mime, :bytes, presence: true

  scope :expired, -> { where(expires_at: ...Time.current) }

  before_validation { self.expires_at ||= TTL.from_now }
end
