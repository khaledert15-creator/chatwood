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

  it 'credits the reply to the agent who sent it even when the conversation is assigned to someone else' do
    customer_message
    create(:agent_assignment_interval, account: account, conversation: conversation, user: other_agent,
                                       started_at: Time.zone.parse('2026-08-11 10:00:00'))
    reply = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                             message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:06:00'))

    described_class.call(reply)

    expect(AgentPerformance::ResponseSample.find_by!(source_message_id: reply.id)).to have_attributes(
      user_id: agent.id, customer_wait_seconds: 360, accountable_wait_seconds: 360, sla_eligible: true, exclusion_reason: nil
    )
  end

  it 'does not time a follow-up message sent before the customer writes again' do
    customer_message
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:01:00'))
    follow_up = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                                 message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:02:00'))

    described_class.call(follow_up)

    expect(AgentPerformance::ResponseSample.find_by!(source_message_id: follow_up.id)).to have_attributes(
      sla_eligible: false, accountable_wait_seconds: nil, exclusion_reason: 'invalid_waiting_episode'
    )
  end
end
