require "rails_helper"

RSpec.describe FinalizeStaleSessionsJob, type: :job do
  it "finalizes sessions whose page has been gone longer than the resume window" do
    stale = create_conversation
    fresh = create_conversation
    stale.update_columns(last_seen_at: 11.minutes.ago)
    fresh.update_columns(last_seen_at: 9.minutes.ago)

    described_class.perform_now

    expect(stale.reload).to have_attributes(status: "finalized", finalize_reason: "abandoned")
    expect(fresh.reload.status).to eq("created")
  end
end
