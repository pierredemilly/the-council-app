module Conversation
  # Derived analytics for a finished session: counts, latency percentiles and provider error tallies.
  module Metrics
    LATENCY_KEYS = %w[stt_ms llm_ms first_clip_ms first_audio_ms].freeze

    def self.summarize(session)
      events = session.events.ordered.to_a
      human = events.select(&:human?)
      {
        "duration_s" => ((session.finalized_at || Time.current) - session.started_at).round,
        "human_turns" => human.size,
        "agent_turns" => events.count(&:agent?),
        "interruptions" => events.count { |e| e.agent? && e.interrupted? },
        "latency" => LATENCY_KEYS.to_h { |key| [ key, percentiles(human.filter_map { |e| e.latency[key] }) ] }.compact,
        "provider_errors" => session.provider_errors.group(:stage).count
      }
    end

    def self.percentiles(values)
      return nil if values.empty?

      sorted = values.sort
      {
        "count" => sorted.size,
        "avg" => (sorted.sum.to_f / sorted.size).round,
        "p50" => percentile(sorted, 0.5),
        "p95" => percentile(sorted, 0.95),
        "max" => sorted.last
      }
    end

    def self.percentile(sorted, fraction)
      sorted[[ (fraction * sorted.size).ceil - 1, 0 ].max]
    end
  end
end
