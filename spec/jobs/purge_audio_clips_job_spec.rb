require "rails_helper"

RSpec.describe PurgeAudioClipsJob, type: :job do
  it "deletes expired clips only" do
    session = create_conversation
    Conversation::Orchestrator.new(session).start_from_utterance!(text: "Hello")
    expired, fresh = session.audio_clips.order(:created_at).first(2)
    expired.update_columns(expires_at: 1.minute.ago)

    described_class.perform_now

    expect(AudioClip.exists?(expired.id)).to be(false)
    expect(AudioClip.exists?(fresh.id)).to be(true)
  end
end
