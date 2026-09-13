require "rails_helper"

RSpec.describe Conversation::ClipSynthesizer do
  let(:session) { create_conversation }
  let(:orchestrator) { Conversation::Orchestrator.new(session) }

  def turns
    session.reload.turns.for_version(session.version).ordered
  end

  it "stores one clip per turn, marks turns ready and announces them with clip urls and timings" do
    orchestrator.start_from_utterance!(text: "Hello")

    expect(turns.pluck(:status)).to all(eq("ready"))
    expect(session.audio_clips.count).to eq(3)
    expect(turns.first.duration_ms).to be > 0
    ready = broadcasts_for(session).select { |m| m["type"] == "agent.turn.ready" }
    expect(ready.size).to eq(3)
    expect(ready.first["payload"]["clipUrl"]).to match(%r{/api/sessions/#{session.id}/clips/[0-9a-f-]+})
    expect(ready.first["payload"]["timings"]).to be_an(Array)
  end

  it "uses word timings from the clip when the visitor interrupts" do
    orchestrator.start_from_utterance!(text: "Hello")
    turn = turns.first
    orchestrator.playback_started!(turn.id)
    halfway = turn.duration_ms / 2

    orchestrator.interrupt!(turn_id: turn.id, position_ms: halfway)

    event = session.reload.events.ordered.last
    expect(event.interrupted).to be(true)
    words = turn.text.split
    expect(event.text.split.size).to be_between(1, words.size - 1)
    expect(session.audio_clips.count).to eq(0)
  end

  it "discards clips whose generation was invalidated while synthesizing" do
    tts = Providers::Tts::Fake.new(session.snapshot)
    allow(tts).to receive(:synthesize).and_wrap_original do |original, **args|
      Conversation::SessionStore.with_lock(session.id) { |s| Conversation::SessionStore.advance_version!(s) }
      original.call(**args)
    end
    orchestrator.start_from_utterance!(text: "Hello")
    session.reload
    pending = session.turns.create!(generation_id: SecureRandom.uuid, version: session.version, position: 0, speaker: "Aphra", text: "late words", status: "pending")

    expect { described_class.new(session, [ pending ], session.version, tts: tts).call }.to raise_error(Conversation::StaleVersion)
    expect(pending.reload.status).to eq("pending")
    expect(AudioClip.where(session_turn_id: pending.id)).to be_empty
  end

  it "reports a recoverable error when synthesis keeps failing" do
    allow_any_instance_of(Providers::Tts::Fake).to receive(:synthesize).and_raise(Providers::Error.new("voice down", recoverable: false))

    orchestrator.start_from_utterance!(text: "Hello")

    expect(session.reload.status).to eq("errored")
    expect(session.turns.where(status: "discarded").count).to eq(3)
    error = broadcasts_for(session).find { |m| m["type"] == "error.recoverable" }
    expect(error["payload"]["message"]).to include("voice down")
  end
end
