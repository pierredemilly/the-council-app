require "rails_helper"

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
RSpec.describe ConversationSession, type: :model do
  it "issues a client token once and only stores its digest" do
    session = create_conversation
    expect(session.client_token).to be_present
    expect(session.client_token_digest).not_to include(session.client_token)
    expect(session.authenticate(session.client_token)).to be(true)
    expect(session.authenticate("nope")).to be(false)
    expect(ConversationSession.find(session.id).client_token).to be_nil
  end

  it "freezes the live configuration and agents at creation" do
    session = create_conversation
    AppConfig.current.update!(max_ai_turns: 2)
    Agent.find_by!(position: 1).update!(name: "Hypatia")

    expect(session.snapshot.max_ai_turns).to eq(6)
    expect(session.snapshot.agent_names).to eq(%w[Aphra Rosa Claudia])
    expect(session.snapshot.public_payload[:agents].first.keys).to contain_exactly("position", "name", "avatar_url")
  end

  it "computes the resume deadline from the snapshot window" do
    session = create_conversation
    expect(session.resume_deadline).to be_within(1.second).of(session.last_seen_at + 600.seconds)
  end
end
