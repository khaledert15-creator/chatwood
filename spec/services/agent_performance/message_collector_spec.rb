require 'rails_helper'

RSpec.describe AgentPerformance::MessageCollector do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  before { account.enable_features!(:agent_performance_analytics) }

  it 'is idempotent across duplicate collection and reconciliation runs' do
    message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                               message_type: :outgoing, sender: agent, private: false)

    2.times { described_class.new(account: account).perform }
    2.times { AgentPerformance::MessageReconciler.new(account: account, since: 1.day.ago).perform }

    expect(AgentPerformance::MessageFact.where(source_message_id: message.id).count).to eq(1)
    expect(AgentPerformance::ResponseSample.where(source_message_id: message.id).count).to eq(1)
  end

  it 'records a failure without changing incoming or outgoing source messages' do
    incoming_message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                                        message_type: :incoming)
    outgoing_message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                                        message_type: :outgoing, sender: agent)
    allow(AgentPerformance::MessageFactProjector).to receive(:call).and_raise('analytics unavailable')

    expect { described_class.new(account: account).perform }.to raise_error('analytics unavailable')
    expect([incoming_message.reload, outgoing_message.reload]).to all(be_persisted)
    expect(AgentPerformance::AnalyticsCursor.find_by(account: account, collector: 'messages').last_error).to eq('analytics unavailable')
  end

  it 'does no analytics work when the feature is disabled' do
    account.disable_features!(:agent_performance_analytics)
    incoming_message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                                        message_type: :incoming)
    outgoing_message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                                        message_type: :outgoing, sender: agent)

    expect(described_class.new(account: account).perform).to be_nil
    expect([incoming_message.reload, outgoing_message.reload]).to all(be_persisted)
    expect(AgentPerformance::MessageFact.where(account: account)).to be_empty
    expect(AgentPerformance::AnalyticsCursor.where(account: account)).to be_empty
  end
end
