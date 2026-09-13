require "rails_helper"

RSpec.describe Conversation::PromptBuilder do
  let(:input) do
    Providers::Llm::Input.new(
      system_prompt: "Be lively.",
      agents: [ { "name" => "Aphra", "personality" => "Restoration playwright." }, { "name" => "Rosa", "personality" => "" }, { "name" => "Claudia", "personality" => "Roman matron." } ],
      transcript: [
        { "kind" => "human", "text" => "Good evening", "interrupted" => false },
        { "kind" => "agent", "speaker" => "Aphra", "text" => "Good evening to", "interrupted" => true },
        { "kind" => "human", "text" => "Sorry, go on", "interrupted" => false }
      ],
      max_turns: 4,
      fallback_language: "fr",
      stage_directions: %w[laughs pause]
    )
  end
  let(:builder) { described_class.new(input) }

  it "combines the editorial prompt, structural rules and character sheets" do
    text = builder.instructions

    expect(text).to start_with("Be lively.")
    expect(text).to include("APHRA, ROSA, CLAUDIA")
    expect(text).to include("At most 4 turns in total and no character speaks more than twice")
    expect(text).to include("[laughs] [pause]")
    expect(text).to include("default: fr")
    expect(text).to include("## APHRA\nRestoration playwright.")
    expect(text).to include("## ROSA\n(no sheet yet)")
    expect(text).not_to include("Write every line in fr")
  end

  it "tells the model which machine-writing habits to avoid" do
    text = builder.instructions

    expect(text).to include("## Sounding human")
    expect(text).to include("no em dashes or en dashes")
    expect(text).to include(%q("it's not X, it's Y"))
    expect(text).to include("No therapy speak")
    expect(text.index("## Sounding human")).to be < text.index("## APHRA")
  end

  it "pins the language once the session knows it" do
    text = described_class.new(input.with(language: "fr")).instructions
    expect(text).to include("Write every line in fr.")
  end

  it "renders the transcript as a script with interruption metadata" do
    content = builder.messages.first[:content]

    expect(content).to include("VISITOR: Good evening")
    expect(content).to include("APHRA: Good evening to (interrupted by the visitor)")
    expect(content).to include("## Interruptions\nThe visitor cut off: line 2 (Aphra).")
    expect(content).to end_with("Continue the conversation from here.")
  end

  it "appends validation feedback as a second message when retrying" do
    messages = builder.messages(feedback: "unknown speaker BEN")

    expect(messages.size).to eq(2)
    expect(messages.last[:role]).to eq(:user)
    expect(messages.last[:content]).to include("rejected: unknown speaker BEN")
  end
end
