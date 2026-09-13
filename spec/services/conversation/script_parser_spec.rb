require "rails_helper"

RSpec.describe Conversation::ScriptParser do
  let(:names) { [ "Aphra Behn", "Rosa", "Claudia" ] }
  let(:directions) { %w[laughs pause] }

  def envelope(dialogue, next_action: "wait_for_user")
    Providers::Llm::Envelope.new(dialogue: dialogue, next_action: next_action, usage: { "input_tokens" => 10 }, latency_ms: 42)
  end

  def parse(dialogue, **opts)
    described_class.parse(envelope(dialogue, **opts), agent_names: names, max_turns: 6, stage_directions: directions)
  end

  it "parses script lines into canonical turns and keeps usage and latency" do
    segment = parse("APHRA BEHN: I disagree.\n\nrosa: That was quick. [laughs]\nClaudia:   What do you think?")

    expect(segment.turns.map(&:speaker)).to eq([ "Aphra Behn", "Rosa", "Claudia" ])
    expect(segment.turns.map(&:text)).to eq([ "I disagree.", "That was quick. [laughs]", "What do you think?" ])
    expect(segment.next_action).to eq("wait_for_user")
    expect(segment.usage).to eq("input_tokens" => 10)
    expect(segment.latency_ms).to eq(42)
  end

  it "accepts Windows line endings and yield_to_user" do
    segment = parse("ROSA: Hm.\r\n\r\nCLAUDIA: Indeed.", next_action: "yield_to_user")
    expect(segment.turns.size).to eq(2)
    expect(segment.next_action).to eq("yield_to_user")
  end

  it "rejects unknown speakers" do
    expect { parse("ROSA: Hi.\n\nBEN: Hello.") }.to raise_error(described_class::Invalid, /unknown speaker BEN/)
  end

  it "rejects lines written for the visitor" do
    expect { parse("ROSA: Hi.\n\nVISITOR: I think so too.") }.to raise_error(described_class::Invalid, /visitor's lines/)
  end

  it "rejects malformed lines and empty dialogue" do
    expect { parse("ROSA: Hi.\n\nJust some narration without a speaker.") }.to raise_error(described_class::Invalid, /malformed line/)
    expect { parse("") }.to raise_error(described_class::Invalid, /empty/)
    expect { parse("ROSA: [laughs]") }.to raise_error(described_class::Invalid, /empty line/)
  end

  it "rejects more than the maximum number of turns" do
    lines = 7.times.map { |i| "#{names[i % 3].upcase}: line #{i}" }.join("\n")
    expect { parse(lines) }.to raise_error(described_class::Invalid, /7 turns exceed the maximum of 6/)
  end

  it "rejects a character speaking more than twice" do
    expect { parse("ROSA: One.\nROSA: Two.\nROSA: Three.") }.to raise_error(described_class::Invalid, /Rosa speaks 3 times/)
  end

  it "rejects unsupported stage directions" do
    expect { parse("ROSA: [screams] No!") }.to raise_error(described_class::Invalid, /unsupported stage direction \[screams\]/)
    expect(parse("ROSA: [Pause] Well.").turns.first.text).to eq("[Pause] Well.")
  end

  it "rejects unknown next actions" do
    expect { parse("ROSA: Hi.", next_action: "stop") }.to raise_error(described_class::Invalid, /next_action/)
  end
end
