module Conversation
  # Bounded in-process pool for provider round trips; see docs/PLAN.md §1.1.
  module Executor
    mattr_accessor :inline, default: false

    def self.pool
      @pool ||= Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: Integer(ENV.fetch("GENERATION_THREADS", 4)),
        max_queue: 64,
        fallback_policy: :caller_runs
      )
    end

    def self.post(&block)
      return run(&block) if inline

      pool.post { run(&block) }
    end

    def self.run
      Rails.application.executor.wrap { yield }
    rescue StandardError => e
      Rails.logger.error("[conversation] background task failed: #{e.class}: #{e.message}")
      raise if inline
    end
  end
end
