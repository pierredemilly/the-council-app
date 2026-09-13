module Providers
  module Registry
    TTS = { "eleven_labs" => Tts::ElevenLabs, "fake" => Tts::Fake }.freeze
    LLM = { "openai" => Llm::OpenaiResponses, "fake" => Llm::Fake }.freeze

    def self.tts(config)
      TTS.fetch(config.tts_provider).new(config)
    end

    def self.llm(config)
      adapter = LLM[config.llm_provider] or
        raise Error.new("LLM provider #{config.llm_provider.inspect} is not available", recoverable: false)
      adapter.new(config)
    end
  end
end
