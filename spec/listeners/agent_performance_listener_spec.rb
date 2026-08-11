require 'rails_helper'

RSpec.describe AgentPerformanceListener do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  before { account.enable_features!(:agent_performance_analytics) }

  it 'does not propagate an analytics enqueue failure' do
    event = Events::Base.new(
      'assignee_changed', Time.current,
      conversation: conversation, changed_attributes: { 'assignee_id' => [nil, 123] }
    )
    allow(AgentPerformance::CaptureAssignmentEventJob).to receive(:perform_later).and_raise('redis unavailable')

    expect { described_class.instance.assignee_changed(event) }.not_to raise_error
  end

  it 'does not enqueue analytics when the feature is disabled' do
    account.disable_features!(:agent_performance_analytics)
    event = Events::Base.new(
      'assignee_changed', Time.current,
      conversation: conversation, changed_attributes: { 'assignee_id' => [nil, 123] }
    )

    expect(AgentPerformance::CaptureAssignmentEventJob).not_to receive(:perform_later)
    expect { described_class.instance.assignee_changed(event) }.not_to raise_error
  end
end
