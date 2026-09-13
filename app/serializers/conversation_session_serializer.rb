# == Schema Information
#
# Table name: conversation_sessions
#
#  id                  :uuid             not null, primary key
#  client_mode         :string           default("browser"), not null
#  client_token_digest :string           not null
#  config_snapshot     :jsonb            not null
#  finalize_reason     :string
#  finalized_at        :datetime
#  first_utterance_at  :datetime
#  language            :string
#  last_activity_at    :datetime         not null
#  last_seen_at        :datetime         not null
#  metrics             :jsonb            not null
#  next_seq            :integer          default(1), not null
#  started_at          :datetime         not null
#  status              :string           default("created"), not null
#  version             :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_conversation_sessions_on_status_and_last_seen_at  (status,last_seen_at)
#
class ConversationSessionSerializer
  include Alba::Resource

  transform_keys :lower_camel

  attributes :id, :status, :client_mode, :version, :language, :started_at

  attribute :last_seq, &:last_seq
  attribute :resume_deadline do |session|
    session.resume_deadline.iso8601
  end
  attribute :config do |session|
    session.snapshot.public_payload
  end
end
