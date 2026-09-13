require "rails_helper"

# == Schema Information
#
# Table name: agents
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  personality :text             default(""), not null
#  position    :integer          not null
#  voice_name  :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  voice_id    :string
#
# Indexes
#
#  index_agents_on_lower_name  (lower((name)::text)) UNIQUE
#  index_agents_on_position    (position) UNIQUE
#
RSpec.describe Agent, type: :model do
  subject(:agent) { Agent.new(position: 1, name: "Aphra") }

  it "is valid with a position and a unique name" do
    expect(agent).to be_valid
  end

  it "rejects colons and line breaks in the name because they break the script format" do
    agent.name = "Aphra: the wise"
    expect(agent).not_to be_valid
    agent.name = "Aphra\nBehn"
    expect(agent).not_to be_valid
  end

  it "rejects names that only differ by case" do
    Agent.create!(position: 2, name: "Rosa")
    agent.name = "rosa"
    expect(agent).not_to be_valid
  end

  it "only allows the three council positions" do
    agent.position = 4
    expect(agent).not_to be_valid
  end

  it "accepts a small PNG avatar and rejects other files" do
    agent.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")
    expect(agent).to be_valid

    agent.avatar.attach(io: file_fixture("avatar.txt").open, filename: "avatar.txt", content_type: "text/plain")
    expect(agent).not_to be_valid
    expect(agent.errors[:avatar]).to be_present
  end
end
