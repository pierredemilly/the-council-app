require "rails_helper"

RSpec.describe Conversation::SegmentGenerator do
  let(:session) { create_conversation }
  let(:llm) { instance_double(Providers::Llm::Fake) }

  def envelope(dialogue)
    Providers::Llm::Envelope.new(dialogue: dialogue, next_action: "wait_for_user", usage: { "input_tokens" => 100, "output_tokens" => 20 }, latency_ms: 5)
  end

  before { Conversation::Orchestrator.new(session).start_from_utterance!(text: "Hello") }

  it "feeds the validation error back to the model and returns the corrected script" do
    expect(llm).to receive(:complete).with(kind_of(Providers::Llm::Input), feedback: nil).ordered.and_return(envelope("BEN: Hi."))
    expect(llm).to receive(:complete).with(kind_of(Providers::Llm::Input), feedback: /unknown speaker BEN/).ordered.and_return(envelope("APHRA: Hi."))

    result = described_class.new(session, llm: llm).call

    expect(result.segment.turns.map(&:speaker)).to eq([ "Aphra" ])
    expect(result.attempts).to eq(2)
    expect(result.usage).to eq("input_tokens" => 200, "output_tokens" => 40)
  end

  it "gives up after the configured number of rejected scripts" do
    session.snapshot.config["retry_count"] = 1
    allow(llm).to receive(:complete).and_return(envelope("BEN: Hi."))

    expect { described_class.new(session, llm: llm).call }.to raise_error(Providers::Error, /invalid script.*unknown speaker BEN/)
    expect(llm).to have_received(:complete).twice
  end

  it "passes the transcript, limits and stage directions to the model" do
    captured = nil
    allow(llm).to receive(:complete) { |input, **| captured = input; envelope("ROSA: Hi.") }

    described_class.new(session, llm: llm).call

    expect(captured.transcript.map { |e| e["text"] }).to eq([ "Hello" ])
    expect(captured.max_turns).to eq(6)
    expect(captured.stage_directions).to include("laughs")
    expect(captured.agents.map { |a| a["name"] }).to eq(%w[Aphra Rosa Claudia])
  end
end
