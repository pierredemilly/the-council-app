module Providers
  module Tts
    class Fake < Base
      VOICES = [
        Voice.new(id: "fake-alto", name: "Fake Alto", labels: { "gender" => "female" }),
        Voice.new(id: "fake-tenor", name: "Fake Tenor", labels: { "gender" => "male" }),
        Voice.new(id: "fake-mezzo", name: "Fake Mezzo", labels: { "gender" => "female" })
      ].freeze

      def voices
        VOICES
      end
    end
  end
end
