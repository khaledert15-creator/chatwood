require 'rails_helper'

RSpec.describe AgentPerformance::MessageClassifier do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'classifies a customer-facing user message as manual' do
    message = build(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                              message_type: :outgoing, sender: agent, private: false)

    expect(described_class.call(message)).to have_attributes(eligible: true, message_kind: 'manual')
  end

  it 'classifies a manually authored provider template separately' do
    message = build(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                              message_type: :outgoing, sender: agent, private: false,
                              additional_attributes: { 'template_params' => { 'name' => 'hello' } })

    expect(described_class.call(message)).to have_attributes(eligible: true, message_kind: 'manual_template')
  end

  it 'excludes private notes, automations, campaigns, system templates, and bots' do
    messages = [
      build(:message, message_type: :outgoing, sender: agent, private: true),
      build(:message, message_type: :outgoing, sender: agent, content_attributes: { 'automation_rule_id' => 1 }),
      build(:message, message_type: :outgoing, sender: agent, additional_attributes: { 'campaign_id' => 1 }),
      build(:message, message_type: :template, sender: agent),
      build(:message, message_type: :outgoing, sender: create(:agent_bot, account: account))
    ]

    expect(messages.map { |message| described_class.call(message).eligible }).to all(be(false))
  end
end
