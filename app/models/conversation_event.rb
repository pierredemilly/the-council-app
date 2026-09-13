# == Schema Information
#
# Table name: conversation_events
#
#  id                      :bigint           not null, primary key
#  interrupted             :boolean          default(FALSE), not null
#  kind                    :string           not null
#  latency                 :jsonb            not null
#  occurred_at             :datetime         not null
#  seq                     :integer          not null
#  speaker                 :string
#  spoken_ms               :integer
#  text                    :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  conversation_session_id :uuid             not null
#
# Indexes
#
#  index_conversation_events_on_conversation_session_id          (conversation_session_id)
#  index_conversation_events_on_conversation_session_id_and_seq  (conversation_session_id,seq) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_session_id => conversation_sessions.id)
#
class ConversationEvent < ApplicationRecord
  KINDS = %w[human agent system].freeze

  belongs_to :conversation_session

  validates :seq, presence: true, uniqueness: { scope: :conversation_session_id }
  validates :kind, inclusion: { in: KINDS }
  validates :speaker, presence: true, if: :agent?
  validates :text, presence: true, unless: :interrupted?

  scope :ordered, -> { order(:seq) }
  scope :spoken, -> { where(kind: %w[human agent]) }

  def agent?
    kind == "agent"
  end

  def human?
    kind == "human"
  end
end
