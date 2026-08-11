require 'rails_helper'

RSpec.describe AgentPerformance::ResponseSampleProjector do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:customer_message) do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :incoming, sender: conversation.contact, created_at: Time.zone.parse('2026-08-11 10:00:00'))
  end

  it 'starts accountable time at assignment after the customer began waiting' do
    customer_message
    create(:agent_assignment_interval, account: account, conversation: conversation, user: agent,
                                       started_at: Time.zone.parse('2026-08-11 10:05:00'))
    reply = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                             message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:06:00'))

    described_class.call(reply)

    expect(AgentPerformance::ResponseSample.find_by!(source_message_id: reply.id)).to have_attributes(
      customer_wait_seconds: 360, accountable_wait_seconds: 60, sla_eligible: true
    )
  end

  it 'counts an unassigned responder message but excludes the response from SLA' do
    customer_message
    create(:agent_assignment_interval, account: account, conversation: conversation, user: other_agent,
                                       started_at: Time.zone.parse('2026-08-11 10:00:00'))
    reply = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                             message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:01:00'))

    AgentPerformance::MessageFactProjector.call(reply)
    described_class.call(reply)

    expect(AgentPerformance::MessageFact.find_by(source_message_id: reply.id)).to be_present
    expect(AgentPerformance::ResponseSample.find_by!(source_message_id: reply.id)).to have_attributes(
      unassigned_responder: true, sla_eligible: false, exclusion_reason: 'unassigned_responder'
    )
  end

  it 'counts a historical message but marks missing assignment history as ineligible' do
    customer_message
    reply = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                             message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:01:00'))

    AgentPerformance::MessageFactProjector.call(reply)
    described_class.call(reply)

    expect(AgentPerformance::MessageFact.find_by(source_message_id: reply.id)).to be_present
    expect(AgentPerformance::ResponseSample.find_by!(source_message_id: reply.id)).to have_attributes(
      assignment_history_missing: true, sla_eligible: false, exclusion_reason: 'assignment_history_missing'
    )
  end
end
