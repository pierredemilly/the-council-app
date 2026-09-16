# == Schema Information
#
# Table name: agents
#
#  id          :bigint           not null, primary key
#  biography   :text             default(""), not null
#  color       :string
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
class Agent < ApplicationRecord
  COUNT = 3
  NAME_CHAR_LIMIT = 40
  PERSONALITY_CHAR_LIMIT = 30_000
  BIOGRAPHY_CHAR_LIMIT = 5_000
  AVATAR_BYTE_LIMIT = 5.megabytes
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  PALETTE = %w[#f59e0b #38bdf8 #f472b6].freeze
  HEX_COLOR = /\A#[0-9a-f]{6}\z/i

  has_one_attached :avatar

  validates :position, presence: true, uniqueness: true, inclusion: { in: 1..COUNT }
  validates :name, presence: true, length: { maximum: NAME_CHAR_LIMIT },
                   uniqueness: { case_sensitive: false },
                   format: { without: /[:\n\r]/, message: "cannot contain colons or line breaks" }
  validates :personality, length: { maximum: PERSONALITY_CHAR_LIMIT }
  validates :biography, length: { maximum: BIOGRAPHY_CHAR_LIMIT }
  validates :voice_id, :voice_name, length: { maximum: 200 }, allow_nil: true
  validates :color, format: { with: HEX_COLOR, message: "must be a hex colour like #f59e0b" }

  before_validation { self.color = (color.presence || PALETTE[(position.to_i - 1) % PALETTE.size]).to_s.downcase }
  validate :avatar_is_a_small_image

  scope :ordered, -> { order(:position) }

  private

  def avatar_is_a_small_image
    return unless avatar.attached?

    errors.add(:avatar, "must be a PNG, JPEG or WebP image") unless avatar.content_type.in?(AVATAR_CONTENT_TYPES)
    errors.add(:avatar, "must be smaller than 5 MB") if avatar.byte_size > AVATAR_BYTE_LIMIT
  end
end
