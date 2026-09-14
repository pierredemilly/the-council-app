# One failed provider attempt, with a sanitized message and no transcript content.
# == Schema Information
#
# Table name: provider_errors
#
#  id                      :bigint           not null, primary key
#  attempt                 :integer          default(1), not null
#  message                 :string           not null
#  provider                :string           not null
#  recoverable             :boolean          default(TRUE), not null
#  stage                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  conversation_session_id :uuid
#
# Indexes
#
#  index_provider_errors_on_conversation_session_id  (conversation_session_id)
#  index_provider_errors_on_stage_and_created_at     (stage,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_session_id => conversation_sessions.id)
#
class ProviderError < ApplicationRecord
  STAGES = %w[llm parse tts stt stt_preview].freeze
  MESSAGE_LIMIT = 300

  belongs_to :conversation_session, optional: true

  validates :stage, inclusion: { in: STAGES }
  validates :provider, :message, presence: true

  def self.record!(session:, stage:, provider:, error:, attempt: 1)
    create!(
      conversation_session: session, stage: stage, provider: provider, attempt: attempt,
      recoverable: error.respond_to?(:recoverable) ? error.recoverable : true,
      message: error.message.to_s.truncate(MESSAGE_LIMIT)
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("[conversation] could not record provider error: #{e.message}")
    nil
  end
end
