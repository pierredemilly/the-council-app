module Providers
  module Llm
    class OpenaiResponses < Base
      MAX_OUTPUT_TOKENS = 1_500
      RECOVERABLE = [
        OpenAI::Errors::APIConnectionError, OpenAI::Errors::RateLimitError, OpenAI::Errors::InternalServerError
      ].freeze

      SCHEMA = {
        type: "object",
        properties: {
          dialogue: { type: "string", description: "Script lines, one per paragraph, formatted as NAME: text" },
          next_action: { type: "string", enum: Conversation::ScriptParser::NEXT_ACTIONS }
        },
        required: %w[dialogue next_action],
        additionalProperties: false
      }.freeze

      def complete(input, feedback: nil)
        builder = Conversation::PromptBuilder.new(input)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        response = client.responses.create(**request_params(builder, feedback))
        latency_ms = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - started

        raise Error.new("OpenAI response #{response.status}", recoverable: true) unless response.status == :completed

        envelope = parse_json(response.output_text)
        Envelope.new(
          dialogue: envelope["dialogue"].to_s,
          next_action: envelope["next_action"].to_s,
          usage: usage_from(response),
          latency_ms: latency_ms
        )
      rescue *RECOVERABLE => e
        raise Error.new("OpenAI request failed: #{e.class.name.demodulize}", recoverable: true)
      rescue OpenAI::Errors::APIError => e
        raise Error.new("OpenAI rejected the request: #{e.class.name.demodulize}", recoverable: false)
      end

      private

      def request_params(builder, feedback)
        params = {
          model: config.llm_model,
          instructions: builder.instructions,
          input: builder.messages(feedback: feedback),
          text: { format: { type: :json_schema, name: "dialogue_segment", strict: true, schema: SCHEMA } },
          max_output_tokens: MAX_OUTPUT_TOKENS,
          store: false
        }
        params[:reasoning] = { effort: config.reasoning_level.to_sym } if config.reasoning_level.present?
        params
      end

      def parse_json(text)
        parsed = JSON.parse(text.to_s)
        raise Error.new("OpenAI returned a non-object envelope", recoverable: true) unless parsed.is_a?(Hash)

        parsed
      rescue JSON::ParserError
        raise Error.new("OpenAI returned malformed JSON", recoverable: true)
      end

      def usage_from(response)
        usage = response.usage
        return {} unless usage

        { "input_tokens" => usage.input_tokens, "output_tokens" => usage.output_tokens, "total_tokens" => usage.total_tokens }
      end

      def client
        @client ||= OpenAI::Client.new(api_key: api_key, timeout: timeout_seconds, max_retries: 0)
      end

      def api_key
        ENV["OPENAI_API_KEY"].presence || raise(MissingCredentials, "OPENAI_API_KEY")
      end

      def timeout_seconds
        ENV.fetch("LLM_TIMEOUT_MS", 30_000).to_i / 1000.0
      end
    end
  end
end
