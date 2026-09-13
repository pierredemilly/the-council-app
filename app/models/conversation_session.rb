# == Schema Information
#
# Table name: conversation_sessions
#
#  id                  :uuid             not null, primary key
#  client_mode         :string           default("browser"), not null
#  client_token_digest :string           not null
#  config_snapshot     :jsonb            not null
#  finalize_reason     :string
#  finalized_at        :datetime
#  first_utterance_at  :datetime
#  language            :string
#  last_activity_at    :datetime         not null
#  last_seen_at        :datetime         not null
#  metrics             :jsonb            not null
#  next_seq            :integer          default(1), not null
#  started_at          :datetime         not null
#  status              :string           default("created"), not null
#  version             :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_conversation_sessions_on_status_and_last_seen_at  (status,last_seen_at)
#
class ConversationSession < ApplicationRecord
  STATUSES = %w[created listening processing speaking finalized errored].freeze
  ACTIVE_STATUSES = (STATUSES - %w[finalized]).freeze
  CLIENT_MODES = %w[browser kiosk].freeze

  has_many :events, class_name: "ConversationEvent", dependent: :delete_all
  # Clips reference turns, so they must go first when a session is destroyed.
  has_many :audio_clips, dependent: :delete_all
  has_many :turns, class_name: "SessionTurn", dependent: :delete_all
  has_many :provider_errors, dependent: :nullify

  attr_reader :client_token

  validates :status, inclusion: { in: STATUSES }
  validates :client_mode, inclusion: { in: CLIENT_MODES }

  before_validation :issue_client_token, on: :create
  before_validation :stamp_timestamps, on: :create

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :abandoned_before, ->(time) { active.where(last_seen_at: ...time) }

  def self.build_from_live_config(client_mode:)
    new(client_mode: client_mode, config_snapshot: Conversation::ConfigSnapshot.capture)
  end

  def authenticate(token)
    return false if token.blank? || client_token_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(self.class.digest(token), client_token_digest)
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def snapshot
    @snapshot ||= Conversation::ConfigSnapshot.new(config_snapshot)
  end

  def active?
    status != "finalized"
  end

  def finalized?
    status == "finalized"
  end

  def last_seq
    next_seq - 1
  end

  def resume_deadline
    last_seen_at + snapshot.resume_window_seconds.seconds
  end

  private

  def issue_client_token
    @client_token = SecureRandom.urlsafe_base64(32)
    self.client_token_digest = self.class.digest(@client_token)
  end

  def stamp_timestamps
    now = Time.current
    self.started_at ||= now
    self.last_seen_at ||= now
    self.last_activity_at ||= now
  end
end
