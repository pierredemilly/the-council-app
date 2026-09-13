require "rails_helper"

RSpec.describe "db/seeds.rb" do
  around do |example|
    original = ENV.slice("ADMIN_EMAIL", "ADMIN_PASSWORD", "LLM_MODEL")
    ENV["ADMIN_EMAIL"] = "admin@example.com"
    ENV["ADMIN_PASSWORD"] = "supersecret123"
    ENV["LLM_MODEL"] = "gpt-test"
    example.run
    original.each { |k, v| ENV[k] = v }
  end

  it "creates the configuration, the three characters and the admin, and is idempotent" do
    2.times { Rails.application.load_seed }

    expect(AppConfig.count).to eq(1)
    expect(AppConfig.current.llm_model).to eq("gpt-test")
    expect(AppConfig.current.global_system_prompt).to be_present
    expect(Agent.ordered.pluck(:name)).to eq(%w[Aphra Rosa Claudia])
    expect(User.pluck(:email)).to eq([ "admin@example.com" ])
  end

  it "keeps admin edits when reseeded" do
    Rails.application.load_seed
    Agent.find_by!(position: 1).update!(name: "Hypatia")
    AppConfig.current.update!(global_system_prompt: "Edited")

    Rails.application.load_seed

    expect(Agent.find_by!(position: 1).name).to eq("Hypatia")
    expect(AppConfig.current.global_system_prompt).to eq("Edited")
  end
end
