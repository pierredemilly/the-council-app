require "rails_helper"

RSpec.describe "TTS synthesis adapters" do
  describe Providers::Tts.method(:word_timings) do
    it "groups character alignment into word timings that match the transcript word split" do
      text = "Hi there [laughs]"
      chars = text.chars
      starts = chars.each_index.map { |i| i * 0.1 }
      ends = chars.each_index.map { |i| i * 0.1 + 0.1 }

      timings = Providers::Tts.word_timings(text, chars, starts, ends)

      expect(timings.map { |t| t["word"] }).to eq(%w[Hi there [laughs]])
      expect(timings.first).to eq("word" => "Hi", "start_ms" => 0, "end_ms" => 200)
      expect(timings.last["end_ms"]).to eq(1700)
    end

    it "returns nil when the alignment is missing or inconsistent" do
      expect(Providers::Tts.word_timings("Hi", nil, nil, nil)).to be_nil
      expect(Providers::Tts.word_timings("Hi there", %w[H i], [ 0 ], [ 0.1 ])).to be_nil
    end
  end

  describe Providers::Tts::Fake do
    it "returns a silent WAV with evenly spread word timings" do
      result = described_class.new(AppConfig.current).synthesize(text: "one two three", voice_id: "fake-alto")

      expect(result.mime).to eq("audio/wav")
      expect(result.audio[0, 4]).to eq("RIFF")
      expect(result.duration_ms).to eq(1200)
      expect(result.timings.map { |t| t["word"] }).to eq(%w[one two three])
      expect(result.timings.last["end_ms"]).to eq(1200)
    end
  end

  describe Providers::Tts::ElevenLabs do
    subject(:provider) { described_class.new(AppConfig.current.tap { |c| c.update!(tts_model: "eleven_v3", tts_settings: { "voice_settings" => { "stability" => 0.4 } }) }) }

    around do |example|
      original = ENV["ELEVENLABS_API_KEY"]
      ENV["ELEVENLABS_API_KEY"] = "test-key"
      example.run
      ENV["ELEVENLABS_API_KEY"] = original
    end

    it "posts to the with-timestamps endpoint and converts the alignment" do
      text = "Hello there"
      chars = text.chars
      stub = stub_request(:post, "https://api.elevenlabs.io/v1/text-to-speech/v1/with-timestamps?output_format=mp3_44100_128")
        .with(headers: { "xi-api-key" => "test-key" }) { |request|
          body = JSON.parse(request.body)
          body["text"] == text && body["model_id"] == "eleven_v3" && body["voice_settings"] == { "stability" => 0.4 } && body["language_code"] == "fr"
        }
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          audio_base64: Base64.strict_encode64("ID3fakemp3"),
          alignment: { characters: chars, character_start_times_seconds: chars.each_index.map { |i| i * 0.1 }, character_end_times_seconds: chars.each_index.map { |i| i * 0.1 + 0.1 } }
        }.to_json)

      result = provider.synthesize(text: text, voice_id: "v1", language: "fr")

      expect(stub).to have_been_requested
      expect(result.audio).to eq("ID3fakemp3")
      expect(result.mime).to eq("audio/mpeg")
      expect(result.duration_ms).to eq(1100)
      expect(result.timings.map { |t| t["word"] }).to eq(%w[Hello there])
    end

    it "fails fast without a voice and maps HTTP failures" do
      expect { provider.synthesize(text: "x", voice_id: nil) }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(false) }

      stub_request(:post, %r{api.elevenlabs.io/v1/text-to-speech/v1/with-timestamps}).to_return(status: 429, body: "{}")
      expect { provider.synthesize(text: "x", voice_id: "v1") }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(true) }

      stub_request(:post, %r{api.elevenlabs.io/v1/text-to-speech/v1/with-timestamps}).to_return(status: 401, body: "{}")
      expect { provider.synthesize(text: "x", voice_id: "v1") }.to raise_error(Providers::Error) { |e| expect(e.recoverable).to be(false) }
    end
  end
end
