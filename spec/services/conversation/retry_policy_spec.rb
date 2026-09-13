require "rails_helper"

RSpec.describe Conversation::RetryPolicy do
  let(:sleeps) { [] }
  let(:policy) { described_class.new(count: 3, base_ms: 100, max_ms: 250, sleeper: ->(s) { sleeps << s }, random: Random.new(1)) }

  it "retries recoverable errors with bounded, jittered backoff and then succeeds" do
    attempts = 0
    result = policy.run do |attempt|
      attempts = attempt
      raise Providers::Error, "flaky" if attempt < 3
      :ok
    end

    expect(result).to eq(:ok)
    expect(attempts).to eq(3)
    expect(sleeps.size).to eq(2)
    expect(sleeps).to all(be_between(0.05, 0.25))
  end

  it "gives up after the configured count" do
    expect { policy.run { raise Providers::Error, "down" } }.to raise_error(Providers::Error, "down")
    expect(sleeps.size).to eq(3)
  end

  it "does not retry non-recoverable errors" do
    expect { policy.run { raise Providers::Error.new("no key", recoverable: false) } }.to raise_error(Providers::Error)
    expect(sleeps).to be_empty
  end

  it "reports every failed attempt to the observer, including the final one" do
    seen = []
    expect {
      policy.run(on_error: ->(error, attempt) { seen << [ error.message, attempt ] }) { raise Providers::Error, "down" }
    }.to raise_error(Providers::Error)
    expect(seen).to eq([ [ "down", 1 ], [ "down", 2 ], [ "down", 3 ], [ "down", 4 ] ])
  end
end
