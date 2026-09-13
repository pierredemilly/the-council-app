module Conversation
  class RetryPolicy
    attr_reader :count, :base_ms, :max_ms

    def initialize(count:, base_ms:, max_ms:, sleeper: Kernel.method(:sleep), random: Random.new)
      @count = count.to_i
      @base_ms = base_ms.to_i
      @max_ms = [ max_ms.to_i, @base_ms ].max
      @sleeper = sleeper
      @random = random
    end

    # on_error receives every failed attempt, including the last one, before the policy decides.
    def run(on_error: nil)
      attempt = 0
      loop do
        attempt += 1
        return yield(attempt)
      rescue Providers::Error => e
        on_error&.call(e, attempt)
        raise if !e.recoverable || attempt > count

        yield_delay(attempt)
      end
    end

    def delay_ms(attempt)
      cap = [ base_ms * (2**(attempt - 1)), max_ms ].min
      @random.rand(cap / 2..cap)
    end

    private

    def yield_delay(attempt)
      @sleeper.call(delay_ms(attempt) / 1000.0)
    end
  end
end
