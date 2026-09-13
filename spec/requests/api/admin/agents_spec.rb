require "rails_helper"

RSpec.describe "Admin agents API", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123") }
  let!(:aphra) { Agent.create!(position: 1, name: "Aphra") }
  let!(:rosa) { Agent.create!(position: 2, name: "Rosa") }

  it "requires a signed-in admin" do
    get "/api/admin/agents", as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists the characters in position order" do
    sign_in_as(admin)
    get "/api/admin/agents", as: :json

    expect(response).to have_http_status(:ok)
    expect(json["agents"].map { |a| a["name"] }).to eq(%w[Aphra Rosa])
    expect(json["agents"].first["avatar_url"]).to be_nil
  end

  it "updates name, personality and voice" do
    sign_in_as(admin)
    patch "/api/admin/agents/#{aphra.id}",
          params: { agent: { name: "Aphra Behn", personality: "Restoration playwright.", voice_id: "v1", voice_name: "Aria" } },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(aphra.reload).to have_attributes(name: "Aphra Behn", personality: "Restoration playwright.", voice_id: "v1", voice_name: "Aria")
  end

  it "rejects a duplicate name" do
    sign_in_as(admin)
    patch "/api/admin/agents/#{aphra.id}", params: { agent: { name: "rosa" } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"].join).to include("Name")
  end

  it "does not allow changing the position" do
    sign_in_as(admin)
    patch "/api/admin/agents/#{aphra.id}", params: { agent: { position: 3, name: "Aphra" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(aphra.reload.position).to eq(1)
  end

  it "uploads and removes an avatar" do
    sign_in_as(admin)
    put "/api/admin/agents/#{aphra.id}/avatar", params: { avatar: fixture_file_upload("avatar.png", "image/png") }

    expect(response).to have_http_status(:ok)
    expect(json.dig("agent", "avatar_url")).to start_with("/rails/active_storage/blobs/")
    expect(aphra.reload.avatar).to be_attached

    delete "/api/admin/agents/#{aphra.id}/avatar", as: :json

    expect(response).to have_http_status(:ok)
    expect(json.dig("agent", "avatar_url")).to be_nil
    expect(aphra.reload.avatar).not_to be_attached
  end

  it "rejects a non-image avatar without keeping it" do
    sign_in_as(admin)
    put "/api/admin/agents/#{aphra.id}/avatar", params: { avatar: fixture_file_upload("avatar.txt", "text/plain") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"].join).to include("Avatar")
    expect(aphra.reload.avatar).not_to be_attached
  end
end
