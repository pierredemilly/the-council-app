class PurgeAudioClipsJob < ApplicationJob
  queue_as :default

  def perform
    AudioClip.expired.in_batches(of: 200).delete_all
  end
end
