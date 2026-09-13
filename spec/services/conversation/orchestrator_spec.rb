require "rails_helper"

RSpec.describe Conversation::Orchestrator do
  include ActiveJob::TestHelper
  let(:session) { create_conversation }
  let(:orchestrator) { described_class.new(session) }

  def turns
    session.reload.turns.for_version(session.version).ordered
  end

  describe "#start_from_utterance!" do
    it "commits the human line, generates a segment and broadcasts it" do
      orchestrator.start_from_utterance!(text: "  Hello council  ")

      expect(session.reload.status).to eq("processing")
      expect(session.events.pluck(:kind, :text)).to eq([ [ "human", "Hello council" ] ])
      expect(session.first_utterance_at).to be_present
      expect(turns.pluck(:speaker, :status)).to eq([ [ "Aphra", "ready" ], [ "Rosa", "ready" ], [ "Claudia", "ready" ] ])
      expect(turns.last.next_action).to eq("wait_for_user")
      expect(broadcast_types(session)).to eq(%w[transcript.committed state.changed agent.turn.ready agent.turn.ready agent.turn.ready])
      expect(broadcasts_for(session).last["payload"]).to include("speaker" => "Claudia", "nextAction" => "wait_for_user")
    end

    it "rejects blank or oversized text and finished sessions" do
      expect { orchestrator.start_from_utterance!(text: "   ") }.to raise_error(ArgumentError)
      expect { orchestrator.start_from_utterance!(text: "x" * 2001) }.to raise_error(ArgumentError)
      orchestrator.finalize!("test")
      expect { orchestrator.start_from_utterance!(text: "hi") }.to raise_error(Conversation::Inactive)
    end

    it "moves to errored with a recoverable error when the provider fails" do
      allow_any_instance_of(Providers::Llm::Fake).to receive(:complete).and_raise(Providers::Error.new("boom", recoverable: false))

      orchestrator.start_from_utterance!(text: "Hello")

      expect(session.reload.status).to eq("errored")
      expect(turns).to be_empty
      error = broadcasts_for(session).find { |m| m["type"] == "error.recoverable" }
      expect(error["payload"]).to include("code" => "generation_failed", "message" => "boom")
    end
  end

  describe "playback" do
    before { orchestrator.start_from_utterance!(text: "Hello") }

    it "commits each turn only once it has been heard, then waits for the visitor" do
      first, second, third = turns.to_a

      orchestrator.playback_started!(first.id)
      expect(session.reload.status).to eq("speaking")
      expect(session.events.count).to eq(1)

      orchestrator.playback_completed!(first.id, spoken_ms: 1500)
      expect(session.reload.events.ordered.last).to have_attributes(kind: "agent", speaker: "Aphra", spoken_ms: 1500, interrupted: false)
      expect(session.status).to eq("speaking")

      orchestrator.playback_completed!(second.id)
      orchestrator.playback_completed!(third.id)
      expect(session.reload.status).to eq("listening")
      expect(session.events.ordered.pluck(:speaker)).to eq([ nil, "Aphra", "Rosa", "Claudia" ])
      expect(broadcasts_for(session).last["payload"]).to eq("status" => "listening", "nextAction" => "wait_for_user")
    end

    it "ignores duplicate or unknown completion reports" do
      first = turns.first
      orchestrator.playback_completed!(first.id)
      orchestrator.playback_completed!(first.id)
      orchestrator.playback_completed!(SecureRandom.uuid)

      expect(session.reload.events.where(kind: "agent").count).to eq(1)
    end
  end

  describe "#interrupt!" do
    before do
      orchestrator.start_from_utterance!(text: "Hello")
      orchestrator.playback_completed!(turns.first.id)
      orchestrator.playback_started!(turns.second.id)
    end

    it "keeps the heard prefix, drops the rest, and invalidates the generation" do
      current = turns.second
      current.update!(duration_ms: 4000)
      version_before = session.reload.version

      orchestrator.interrupt!(turn_id: current.id, position_ms: 2000)

      session.reload
      expect(session.status).to eq("listening")
      expect(session.version).to be > version_before
      last = session.events.ordered.last
      expect(last.interrupted).to be(true)
      expect(last.speaker).to eq("Rosa")
      expect(current.text).to start_with(last.text)
      expect(last.text.split.size).to be < current.text.split.size
      expect(session.turns.where(status: "discarded").count).to eq(2)
      expect(broadcast_types(session).last(3)).to eq(%w[agent.segment.cancel transcript.committed state.changed])
    end

    it "commits nothing from the current turn when the visitor spoke before any word was heard" do
      current = turns.second
      orchestrator.interrupt!(turn_id: current.id, position_ms: 0)

      expect(session.reload.events.where(speaker: "Rosa")).to be_empty
      expect(session.turns.pending_playback).to be_empty
      expect(session.status).to eq("listening")
    end

    it "only acknowledges with a cancel while already listening" do
      orchestrator.interrupt!
      version = session.reload.version
      types_before = broadcast_types(session).size

      orchestrator.interrupt!

      expect(broadcast_types(session).last(broadcast_types(session).size - types_before)).to eq(%w[agent.segment.cancel])
      expect(session.reload.version).to eq(version)
    end

    it "makes the next utterance carry the interruption into the prompt" do
      current = turns.second
      current.update!(duration_ms: 4000)
      orchestrator.interrupt!(turn_id: current.id, position_ms: 2000)

      orchestrator.start_from_utterance!(text: "Wait, no")

      expect(turns.first.text).to include("cut me off")
    end
  end

  describe "#request_turn!" do
    it "starts a new generation after a yield or an error, but never mid-segment" do
      orchestrator.start_from_utterance!(text: "Hello")
      turns.each { |t| orchestrator.playback_completed!(t.id) }
      version = session.reload.version

      orchestrator.request_turn!

      expect(session.reload.status).to eq("processing")
      expect(session.version).to eq(version + 1)
      expect(turns.count).to eq(3)

      orchestrator.request_turn!
      expect(session.reload.version).to eq(version + 1)
    end

    it "does nothing before the first human utterance" do
      orchestrator.request_turn!
      expect(session.reload.status).to eq("created")
    end
  end

  describe "stale generation results" do
    it "discards a result whose version moved while the provider was working" do
      orchestrator.start_from_utterance!(text: "Hello")
      version = session.reload.version
      orchestrator.interrupt!

      Conversation::SegmentRunner.new(session.id, version).run

      expect(session.reload.turns.for_version(version).where(status: "ready")).to be_empty
      expect(session.status).to eq("listening")
    end
  end

  describe "#finalize!" do
    it "stores metrics and stops accepting messages" do
      orchestrator.start_from_utterance!(text: "Hello")
      orchestrator.playback_completed!(turns.first.id)

      perform_enqueued_jobs { orchestrator.finalize!("inactivity") }

      session.reload
      expect(session).to have_attributes(status: "finalized", finalize_reason: "inactivity")
      expect(session.metrics).to include("human_turns" => 1, "agent_turns" => 1, "interruptions" => 0)
      expect(session.metrics["latency"]).to be_a(Hash)
      expect(session.turns.pending_playback).to be_empty
      expect(broadcasts_for(session).last["payload"]).to eq("status" => "finalized", "reason" => "inactivity")
      expect { orchestrator.request_turn! }.to raise_error(Conversation::Inactive)
    end
  end

  describe "#ready_payload" do
    it "gives a reconnecting client everything it needs to reconcile" do
      orchestrator.start_from_utterance!(text: "Hello")
      orchestrator.playback_completed!(turns.first.id)

      payload = orchestrator.ready_payload

      expect(payload[:status]).to eq("processing")
      expect(payload[:events].map { |e| e["seq"] }).to eq([ 1, 2 ])
      expect(payload[:pendingTurns].map { |t| t["speaker"] }).to eq(%w[Rosa Claudia])
      expect(payload[:config][:agents].size).to eq(3)
    end
  end

  describe "next_action continue" do
    it "starts the next segment as soon as the last line is spoken, without waiting for the visitor" do
      llm = instance_double(Providers::Llm::Fake)
      allow(Providers::Llm::Fake).to receive(:new).and_return(llm)
      allow(llm).to receive(:complete).and_return(
        Providers::Llm::Envelope.new(dialogue: "APHRA: Rosa, do you agree?", next_action: "wait_for_user"),
        Providers::Llm::Envelope.new(dialogue: "ROSA: Not at all. What do you think?", next_action: "wait_for_user")
      )
      orchestrator.start_from_utterance!(text: "Hello")
      first = turns.first
      expect(first.next_action).to eq("continue")

      orchestrator.playback_completed!(first.id)

      session.reload
      expect(session.events.where(kind: "agent").pluck(:text)).to eq([ "Rosa, do you agree?" ])
      expect(turns.pluck(:speaker, :next_action)).to eq([ [ "Rosa", "wait_for_user" ] ])
      expect(broadcast_types(session).last(2)).to eq(%w[state.changed agent.turn.ready])
    end
  end

  describe "an utterance while an answer is queued" do
    it "cancels the queued answer on the browser too" do
      orchestrator.start_from_utterance!(text: "First question")
      expect(turns.count).to eq(3)

      orchestrator.start_from_utterance!(text: "Actually, second question")

      types = broadcast_types(session)
      expect(types.count("agent.segment.cancel")).to eq(1)
      expect(session.reload.turns.where(status: "discarded").count).to eq(3)
      expect(turns.count).to eq(3)
    end

    it "does not send a cancel when nothing was pending" do
      orchestrator.start_from_utterance!(text: "Hello")
      turns.each { |t| orchestrator.playback_completed!(t.id) }
      before = broadcast_types(session).count("agent.segment.cancel")

      orchestrator.start_from_utterance!(text: "Another")

      expect(broadcast_types(session).count("agent.segment.cancel")).to eq(before)
    end
  end
end
