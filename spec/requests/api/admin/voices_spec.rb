require "rails_helper"

RSpec.describe "Admin voices API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123") }

  before { Rails.cache.clear }

  it "requires a signed-in admin" do
    get "/api/admin/voices", as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists the voices of the configured TTS provider" do
    AppConfig.current.update!(tts_provider: "fake")
    sign_in_as(admin)
    get "/api/admin/voices", as: :json

    expect(response).to have_http_status(:ok)
    expect(json["voices"].map { |v| v["name"] }).to include("Fake Alto")
  end

  it "reports provider failures as a bad gateway" do
    original = ENV["ELEVENLABS_API_KEY"]
    ENV["ELEVENLABS_API_KEY"] = nil
    sign_in_as(admin)
    get "/api/admin/voices", as: :json

    expect(response).to have_http_status(:bad_gateway)
    expect(json["error"]).to include("ELEVENLABS_API_KEY")
  ensure
    ENV["ELEVENLABS_API_KEY"] = original
  end
end
