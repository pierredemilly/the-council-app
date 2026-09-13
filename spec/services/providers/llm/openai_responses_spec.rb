require "rails_helper"

RSpec.describe Providers::Llm::OpenaiResponses do
  let(:config) { AppConfig.current.tap { |c| c.update!(llm_model: "gpt-5.6-luna", reasoning_level: "none") } }
  subject(:provider) { described_class.new(config) }

  let(:input) do
    Providers::Llm::Input.new(
      system_prompt: "Be lively.",
      agents: [ { "name" => "Aphra", "personality" => "x" }, { "name" => "Rosa", "personality" => "y" }, { "name" => "Claudia", "personality" => "z" } ],
      transcript: [ { "kind" => "human", "text" => "Hello", "interrupted" => false } ],
      stage_directions: %w[laughs]
    )
  end

  def response_body(text, status: "completed")
    {
      id: "resp_1", object: "response", created_at: 1, model: "gpt-5.6-luna", status: status,
      output: [ { id: "msg_1", type: "message", role: "assistant", status: "completed",
                  content: [ { type: "output_text", text: text, annotations: [] } ] } ],
      usage: { input_tokens: 120, output_tokens: 30, total_tokens: 150, input_tokens_details: { cached_tokens: 0 }, output_tokens_details: { reasoning_tokens: 0 } },
      parallel_tool_calls: false, tool_choice: "auto", tools: [], incomplete_details: (status == "incomplete" ? { reason: "max_output_tokens" } : nil)
    }.to_json
  end

  around do |example|
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "sk-test"
    example.run
    ENV["OPENAI_API_KEY"] = original
  end

  it "sends the structured-output request and returns the envelope with usage" do
    stub = stub_request(:post, "https://api.openai.com/v1/responses")
      .with(headers: { "Authorization" => "Bearer sk-test" }) { |request|
        body = JSON.parse(request.body)
        body["model"] == "gpt-5.6-luna" &&
          body["reasoning"] == { "effort" => "none" } &&
          body["store"] == false &&
          body.dig("text", "format", "type") == "json_schema" &&
          body.dig("text", "format", "strict") == true &&
          body["instructions"].include?("APHRA, ROSA, CLAUDIA") &&
          body["input"].first["content"].include?("VISITOR: Hello")
      }
      .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                 body: response_body({ dialogue: "APHRA: Hello there.\n\nROSA: Welcome.", next_action: "wait_for_user" }.to_json))

    envelope = provider.complete(input)

    expect(stub).to have_been_requested
    expect(envelope.dialogue).to eq("APHRA: Hello there.\n\nROSA: Welcome.")
    expect(envelope.next_action).to eq("wait_for_user")
    expect(envelope.usage).to eq("input_tokens" => 120, "output_tokens" => 30, "total_tokens" => 150)
    expect(envelope.latency_ms).to be >= 0
  end

  it "includes validation feedback as an extra input message" do
    stub = stub_request(:post, "https://api.openai.com/v1/responses") { |request|
      JSON.parse(request.body)["input"].last["content"].include?("rejected: unknown speaker BEN")
    }.to_return(status: 200, headers: { "Content-Type" => "application/json" },
                body: response_body({ dialogue: "APHRA: Hi.", next_action: "wait_for_user" }.to_json))

    provider.complete(input, feedback: "unknown speaker BEN")
    expect(stub).to have_been_requested
  end

  it "treats rate limits, server errors and timeouts as recoverable" do
    stub_request(:post, "https://api.openai.com/v1/responses").to_return(status: 429, body: { error: { message: "slow down" } }.to_json, headers: { "Content-Type" => "application/json" })
    expect { provider.complete(input) }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(true) }

    stub_request(:post, "https://api.openai.com/v1/responses").to_timeout
    expect { provider.complete(input) }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(true) }

    stub_request(:post, "https://api.openai.com/v1/responses").to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: response_body("{}", status: "incomplete"))
    expect { provider.complete(input) }.to raise_error(Providers::Error, /incomplete/) { |e| expect(e.recoverable).to be(true) }
  end

  it "treats authentication and bad requests as non-recoverable" do
    stub_request(:post, "https://api.openai.com/v1/responses").to_return(status: 401, body: { error: { message: "bad key" } }.to_json, headers: { "Content-Type" => "application/json" })
    expect { provider.complete(input) }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(false) }

    ENV["OPENAI_API_KEY"] = nil
    expect { described_class.new(config).complete(input) }.to raise_error(Providers::MissingCredentials)
  end

  it "rejects malformed JSON as recoverable so the retry policy can try again" do
    stub_request(:post, "https://api.openai.com/v1/responses").to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: response_body("not json"))
    expect { provider.complete(input) }.to raise_error(Providers::Error, /malformed JSON/)
  end
end
