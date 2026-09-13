# == Schema Information
#
# Table name: session_turns
#
#  id                      :uuid             not null, primary key
#  duration_ms             :integer
#  next_action             :string
#  position                :integer          not null
#  speaker                 :string           not null
#  status                  :string           default("pending"), not null
#  text                    :text             not null
#  version                 :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  conversation_session_id :uuid             not null
#  generation_id           :uuid             not null
#
# Indexes
#
#  index_session_turns_on_conversation_session_id             (conversation_session_id)
#  index_session_turns_on_conversation_session_id_and_status  (conversation_session_id,status)
#  index_session_turns_on_generation_position                 (conversation_session_id,generation_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_session_id => conversation_sessions.id)
#
class SessionTurnSerializer
  include Alba::Resource

  transform_keys :lower_camel

  attributes :id, :generation_id, :version, :position, :speaker, :text, :next_action, :status, :duration_ms

  attribute :clip_url do |turn|
    "/api/sessions/#{turn.conversation_session_id}/clips/#{turn.audio_clip.id}" if turn.audio_clip
  end

  attribute :timings do |turn|
    turn.audio_clip&.timings
  end
end
