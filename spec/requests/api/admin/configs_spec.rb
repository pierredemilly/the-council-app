require "rails_helper"

RSpec.describe "Admin configuration API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123") }

  it "requires a signed-in admin" do
    get "/api/admin/config", as: :json
    expect(response).to have_http_status(:unauthorized)

    patch "/api/admin/config", params: { config: { llm_model: "x" } }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the live configuration with the allowed options" do
    sign_in_as(admin)
    get "/api/admin/config", as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("config", "max_ai_turns")).to eq(6)
    expect(json.dig("options", "tts_providers")).to include("eleven_labs", "fake")
  end

  it "updates the configuration" do
    sign_in_as(admin)
    patch "/api/admin/config", params: {
      config: { llm_model: "gpt-next", reasoning_level: "low", vad_settings: { positive_speech_threshold: 0.7 }, retry_count: 5 }
    }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("config", "llm_model")).to eq("gpt-next")
    expect(AppConfig.current.reload).to have_attributes(
      llm_model: "gpt-next", reasoning_level: "low", retry_count: 5, vad_settings: { "positive_speech_threshold" => 0.7 }
    )
  end

  it "rejects invalid values with error messages" do
    sign_in_as(admin)
    patch "/api/admin/config", params: { config: { max_ai_turns: 9 } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"].join).to include("Max ai turns")
    expect(AppConfig.current.max_ai_turns).to eq(6)
  end

  it "ignores attributes that are not admin-editable" do
    sign_in_as(admin)
    patch "/api/admin/config", params: { config: { id: 99, llm_model: "gpt-next" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(AppConfig.current.id).not_to eq(99)
  end
end
