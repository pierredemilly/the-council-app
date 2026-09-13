module Providers
  module Registry
    TTS = { "eleven_labs" => Tts::ElevenLabs, "fake" => Tts::Fake }.freeze

    def self.tts(config)
      TTS.fetch(config.tts_provider).new(config)
    end
  end
end
