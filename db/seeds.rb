config = AppConfig.current
if config.global_system_prompt.blank?
  config.update!(
    llm_model: ENV.fetch("LLM_MODEL", config.llm_model),
    global_system_prompt: Rails.root.join("db/seeds/global_system_prompt.txt").read
  )
end

[ "Aphra", "Rosa", "Claudia" ].each.with_index(1) do |name, position|
  Agent.find_or_create_by!(position: position) do |agent|
    agent.name = name
    agent.color = Agent::PALETTE[position - 1]
    agent.personality = Rails.root.join("db/seeds/placeholder_personality.txt").read.gsub("{name}", name)
  end
end

if User.none? && ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  User.create!(email: ENV["ADMIN_EMAIL"], password: ENV["ADMIN_PASSWORD"])
end
