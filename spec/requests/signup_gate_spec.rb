require "rails_helper"

RSpec.describe "Signup gate", type: :request do
  let(:params) { { user: { email: "new@example.com", password: "password123", password_confirmation: "password123" } } }

  def json
    JSON.parse(response.body)
  end

  it "exposes whether signup is enabled to the frontend" do
    get "/current_user", as: :json
    expect(json).to eq("user" => nil, "signup_enabled" => true)
  end

  context "in production" do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    it "refuses signups unless ALLOW_SIGNUP is true" do
      post user_registration_path, params: params, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(User.count).to eq(0)

      get "/current_user", as: :json
      expect(json["signup_enabled"]).to be(false)
    end

    it "allows signups when ALLOW_SIGNUP is true" do
      original = ENV["ALLOW_SIGNUP"]
      ENV["ALLOW_SIGNUP"] = "true"
      post user_registration_path, params: params, as: :json
      expect(response).to have_http_status(:created)
    ensure
      ENV["ALLOW_SIGNUP"] = original
    end
  end
end
