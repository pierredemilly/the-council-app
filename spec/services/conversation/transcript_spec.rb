require "rails_helper"

RSpec.describe Conversation::Transcript do
  let(:text) { "I disagree with you completely" }
  let(:timings) do
    %w[I disagree with you completely].each_with_index.map { |w, i| { "word" => w, "start_ms" => i * 400, "end_ms" => i * 400 + 350 } }
  end

  it "keeps only the words whose end time precedes the stop position" do
    expect(described_class.spoken_prefix(text: text, position_ms: 1200, timings: timings)).to eq("I disagree with")
    expect(described_class.spoken_prefix(text: text, position_ms: 100, timings: timings)).to eq("")
    expect(described_class.spoken_prefix(text: text, position_ms: 5000, timings: timings)).to eq(text)
  end

  it "falls back to a conservative proportional estimate without timings" do
    expect(described_class.spoken_prefix(text: text, position_ms: 1000, duration_ms: 2000)).to eq("I disagree")
    expect(described_class.spoken_prefix(text: text, position_ms: 2500, duration_ms: 2000)).to eq(text)
  end

  it "commits nothing when the position is unknown" do
    expect(described_class.spoken_prefix(text: text, position_ms: 0)).to eq("")
    expect(described_class.spoken_prefix(text: text, position_ms: 900)).to eq("")
  end
end
