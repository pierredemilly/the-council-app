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
class Agent < ApplicationRecord
  COUNT = 3
  NAME_CHAR_LIMIT = 40
  PERSONALITY_CHAR_LIMIT = 30_000
  AVATAR_BYTE_LIMIT = 5.megabytes
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  has_one_attached :avatar

  validates :position, presence: true, uniqueness: true, inclusion: { in: 1..COUNT }
  validates :name, presence: true, length: { maximum: NAME_CHAR_LIMIT },
                   uniqueness: { case_sensitive: false },
                   format: { without: /[:\n\r]/, message: "cannot contain colons or line breaks" }
  validates :personality, length: { maximum: PERSONALITY_CHAR_LIMIT }
  validates :voice_id, :voice_name, length: { maximum: 200 }, allow_nil: true
  validate :avatar_is_a_small_image

  scope :ordered, -> { order(:position) }

  private

  def avatar_is_a_small_image
    return unless avatar.attached?

    errors.add(:avatar, "must be a PNG, JPEG or WebP image") unless avatar.content_type.in?(AVATAR_CONTENT_TYPES)
    errors.add(:avatar, "must be smaller than 5 MB") if avatar.byte_size > AVATAR_BYTE_LIMIT
  end
end
