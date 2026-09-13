require "rails_helper"

# Interruptions arriving at every stage of a segment's life must leave the transcript honest and the session moving.
RSpec.describe "Interruption races" do
  let(:session) { create_conversation }
  let(:orchestrator) { Conversation::Orchestrator.new(session) }

  def turns
    session.reload.turns.for_version(session.version).ordered
  end

  it "during generation: the in-flight result is discarded and the next utterance restarts cleanly" do
    Conversation::Executor.inline = false
    orchestrator.start_from_utterance!(text: "Hello")
    version = session.reload.version
    expect(session.status).to eq("processing")

    orchestrator.interrupt!
    Conversation::SegmentRunner.new(session.id, version).run

    expect(session.reload.status).to eq("listening")
    expect(session.turns.where(status: "ready")).to be_empty
    expect(session.audio_clips).to be_empty

    Conversation::Executor.inline = true
    orchestrator.start_from_utterance!(text: "Are you there?")
    expect(turns.pluck(:status)).to all(eq("ready"))
    expect(session.events.pluck(:text)).to eq([ "Hello", "Are you there?" ])
  ensure
    Conversation::Executor.inline = true
  end

  it "during clip preparation: clips finishing after the interruption are never stored" do
    tts = Providers::Tts::Fake.new(AppConfig.current)
    allow(tts).to receive(:synthesize).and_wrap_original do |original, **args|
      orchestrator.interrupt! if session.reload.status == "processing"
      original.call(**args)
    end
    orchestrator.start_from_utterance!(text: "Hello")
    session.reload
    turn = session.turns.create!(generation_id: SecureRandom.uuid, version: session.version, position: 0, speaker: "Aphra", text: "never heard", status: "pending")
    session.update!(status: "processing")

    expect { Conversation::ClipSynthesizer.new(session, [ turn ], session.version, tts: tts).call }.to raise_error(Conversation::StaleVersion)

    expect(session.reload.status).to eq("listening")
    expect(session.audio_clips).to be_empty
    expect(session.events.where(kind: "agent")).to be_empty
  end

  it "between clips: nothing of the unplayed turns reaches the transcript and their clips are deleted" do
    orchestrator.start_from_utterance!(text: "Hello")
    orchestrator.playback_completed!(turns.first.id)
    expect(session.reload.audio_clips.count).to eq(2)

    orchestrator.interrupt!

    expect(session.reload.events.where(kind: "agent").pluck(:speaker)).to eq([ "Aphra" ])
    expect(session.turns.where(status: "discarded").count).to eq(2)
    expect(session.audio_clips.count).to eq(0)
    expect(session.status).to eq("listening")
  end

  it "with a stale turn id from an earlier generation: no text is committed and the version still moves" do
    orchestrator.start_from_utterance!(text: "Hello")
    old_turn = turns.second
    orchestrator.interrupt!
    orchestrator.start_from_utterance!(text: "Again")
    orchestrator.playback_started!(turns.first.id)
    version = session.reload.version

    orchestrator.interrupt!(turn_id: old_turn.id, position_ms: 900, duration_ms: 1000)

    expect(session.reload.events.where(text: old_turn.text)).to be_empty
    expect(session.version).to eq(version + 1)
    expect(session.status).to eq("listening")
  end

  it "a typed or spoken utterance while a turn plays commits only the heard prefix of that turn" do
    orchestrator.start_from_utterance!(text: "Hello")
    playing = turns.first
    orchestrator.playback_started!(playing.id)

    orchestrator.interrupt!(turn_id: playing.id, position_ms: playing.duration_ms / 2)
    orchestrator.start_from_utterance!(text: "Sorry, one question")

    events = session.reload.events.ordered
    expect(events.map(&:kind)).to eq(%w[human agent human])
    expect(events.second.interrupted).to be(true)
    expect(playing.text).to start_with(events.second.text)
    expect(turns.count).to eq(3)
  end

  it "duplicate completion reports after a reconnect never duplicate transcript events" do
    orchestrator.start_from_utterance!(text: "Hello")
    first = turns.first
    orchestrator.playback_started!(first.id)
    orchestrator.playback_completed!(first.id)

    ready = orchestrator.ready_payload
    orchestrator.playback_completed!(first.id)

    expect(session.reload.events.where(kind: "agent").count).to eq(1)
    expect(ready[:events].size).to eq(2)
    expect(ready[:pendingTurns].map { |t| t["speaker"] }).to eq(%w[Rosa Claudia])
  end
end
