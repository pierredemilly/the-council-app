# == Schema Information
#
# Table name: session_turns
#
#  id                      :uuid             not null, primary key
#  duration_ms             :integer
#  next_action             :string
#  position                :integer          not null
#  speaker                 :string           not null
#  status                  :string           default("pending"), not null
#  text                    :text             not null
#  version                 :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  conversation_session_id :uuid             not null
#  generation_id           :uuid             not null
#
# Indexes
#
#  index_session_turns_on_conversation_session_id             (conversation_session_id)
#  index_session_turns_on_conversation_session_id_and_status  (conversation_session_id,status)
#  index_session_turns_on_generation_position                 (conversation_session_id,generation_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_session_id => conversation_sessions.id)
#
class SessionTurn < ApplicationRecord
  STATUSES = %w[pending ready playing spoken discarded].freeze
  NEXT_ACTIONS = %w[wait_for_user yield_to_user continue].freeze

  belongs_to :conversation_session
  has_one :audio_clip, dependent: :delete

  validates :status, inclusion: { in: STATUSES }
  validates :next_action, inclusion: { in: NEXT_ACTIONS }, allow_nil: true
  validates :speaker, :text, presence: true

  scope :ordered, -> { order(:position) }
  scope :pending_playback, -> { where(status: %w[pending ready playing]) }
  scope :for_version, ->(version) { where(version: version) }

  def spoken?
    status == "spoken"
  end

  def last_in_segment?
    next_action.present?
  end
end
