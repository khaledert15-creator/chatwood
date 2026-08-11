require 'rails_helper'

RSpec.describe AgentPerformance::AssignmentEventProcessor do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:occurred_at) { Time.zone.parse('2026-08-11 10:05:00') }

  it 'closes the previous interval and opens the new interval idempotently' do
    create(:agent_assignment_interval, account: account, conversation: conversation, user: other_agent,
                                       started_at: occurred_at - 5.minutes)
    processor = described_class.new(
      account: account, conversation_id: conversation.id, previous_assignee_id: other_agent.id,
      current_assignee_id: agent.id, occurred_at: occurred_at, source_event_id: 'transfer-1'
    )

    2.times { processor.perform }

    expect(AgentPerformance::AssignmentInterval.where(account: account, conversation: conversation).count).to eq(2)
    expect(AgentPerformance::AssignmentInterval.find_by!(user: other_agent).ended_at).to eq(occurred_at)
    expect(AgentPerformance::AssignmentInterval.find_by!(user: agent)).to have_attributes(started_at: occurred_at, ended_at: nil)
  end
end
