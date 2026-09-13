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
class AgentSerializer
  include Alba::Resource
  include Rails.application.routes.url_helpers

  attributes :id, :position, :name, :personality, :voice_id, :voice_name, :updated_at

  attribute :avatar_url do |agent|
    rails_blob_path(agent.avatar, only_path: true) if agent.avatar.attached?
  end
end
