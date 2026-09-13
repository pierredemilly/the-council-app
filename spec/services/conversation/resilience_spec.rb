require "rails_helper"

RSpec.describe "Resilience bookkeeping" do
  include ActiveJob::TestHelper

  let(:session) { create_conversation }
  let(:orchestrator) { Conversation::Orchestrator.new(session) }

  it "records each failed provider attempt with a sanitized message and no transcript" do
    AppConfig.current.update!(retry_count: 2, retry_base_ms: 50, retry_max_ms: 100)
    calls = 0
    allow_any_instance_of(Providers::Llm::Fake).to receive(:complete) do |*|
      calls += 1
      raise Providers::Error.new("upstream 503 " + ("x" * 400), recoverable: true) if calls < 3
      Providers::Llm::Envelope.new(dialogue: "APHRA: Hi.", next_action: "wait_for_user")
    end
    allow_any_instance_of(Conversation::RetryPolicy).to receive(:yield_delay)

    orchestrator.start_from_utterance!(text: "Hello")

    errors = session.reload.provider_errors.order(:attempt)
    expect(errors.pluck(:stage, :provider, :attempt, :recoverable)).to eq([ [ "llm", "fake", 1, true ], [ "llm", "fake", 2, true ] ])
    expect(errors.first.message.length).to be <= 300
    expect(session.status).to eq("processing")
  end

  it "records rejected scripts under the parse stage" do
    allow_any_instance_of(Providers::Llm::Fake).to receive(:complete).and_return(
      Providers::Llm::Envelope.new(dialogue: "BEN: Hi.", next_action: "wait_for_user"),
      Providers::Llm::Envelope.new(dialogue: "APHRA: Hi.", next_action: "wait_for_user")
    )

    orchestrator.start_from_utterance!(text: "Hello")

    expect(session.reload.provider_errors.pluck(:stage, :message)).to eq([ [ "parse", "unknown speaker BEN" ] ])
  end

  it "measures the time to the first audible word and aggregates latencies on finalize" do
    orchestrator.start_from_utterance!(text: "Hello")
    trigger = session.reload.events.first
    trigger.update!(occurred_at: 1.5.seconds.ago)
    first = session.turns.for_version(session.version).ordered.first

    orchestrator.playback_started!(first.id, duration_ms: 2000)
    expect(session.reload.events.first.latency["first_audio_ms"]).to be_between(1400, 2500)

    orchestrator.playback_completed!(first.id)
    perform_enqueued_jobs { orchestrator.finalize!("test") }

    latency = session.reload.metrics.fetch("latency")
    expect(latency["first_audio_ms"]).to include("count" => 1, "p50" => be_between(1400, 2500), "p95" => be_between(1400, 2500))
    expect(latency["llm_ms"]["count"]).to eq(1)
    expect(session.metrics["provider_errors"]).to eq({})
  end

  it "computes percentiles over the finished sessions' human turns" do
    expect(Conversation::Metrics.percentiles([ 300, 100, 200, 400, 1000 ])).to eq("count" => 5, "avg" => 400, "p50" => 300, "p95" => 1000, "max" => 1000)
    expect(Conversation::Metrics.percentiles([])).to be_nil
  end
end
