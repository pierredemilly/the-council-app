require "rails_helper"

RSpec.describe Providers::Tts::ElevenLabs do
  subject(:provider) { described_class.new(AppConfig.current) }

  around do |example|
    original = ENV["ELEVENLABS_API_KEY"]
    ENV["ELEVENLABS_API_KEY"] = "test-key"
    example.run
    ENV["ELEVENLABS_API_KEY"] = original
  end

  describe "#voices" do
    it "maps the API response to voices" do
      stub_request(:get, "https://api.elevenlabs.io/v1/voices")
        .with(headers: { "xi-api-key" => "test-key" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          voices: [ { voice_id: "v1", name: "Aria", preview_url: "https://x/aria.mp3", labels: { gender: "female" } } ]
        }.to_json)

      voices = provider.voices

      expect(voices.map(&:id)).to eq([ "v1" ])
      expect(voices.first.name).to eq("Aria")
      expect(voices.first.labels).to eq("gender" => "female")
    end

    it "raises a non-recoverable error without an API key" do
      ENV["ELEVENLABS_API_KEY"] = nil
      expect { provider.voices }.to raise_error(Providers::MissingCredentials) { |e| expect(e.recoverable).to be(false) }
    end

    it "raises a provider error on HTTP failures" do
      stub_request(:get, "https://api.elevenlabs.io/v1/voices").to_return(status: 401, body: "{}")
      expect { provider.voices }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(false) }

      stub_request(:get, "https://api.elevenlabs.io/v1/voices").to_timeout
      expect { provider.voices }.to raise_error(Providers::Error)
    end
  end
end
