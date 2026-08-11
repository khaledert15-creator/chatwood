require 'rails_helper'

RSpec.describe 'Agent performance metric audit', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:date) { Date.new(2026, 8, 11) }
  let(:headers) { admin.create_new_auth_token }

  it 'reconciles known source messages, facts, response samples, rollup, and API values' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    account.enable_features!(:agent_performance_analytics)
    create(:agent_performance_target, account: account, user: agent, created_by: admin,
                                      metric: 'response_sla_compliance', target_value: 100,
                                      threshold_seconds: 180, effective_from: date)

    repeated_conversation = create(:conversation, account: account)
    create(:message, account: account, conversation: repeated_conversation, inbox: repeated_conversation.inbox,
                     message_type: :incoming, created_at: Time.zone.parse('2026-08-11 08:59:00'))
    create(:agent_assignment_interval, account: account, conversation: repeated_conversation, user: agent,
                                       started_at: Time.zone.parse('2026-08-11 08:59:00'))
    10.times do |index|
      create(:message, account: account, conversation: repeated_conversation, inbox: repeated_conversation.inbox,
                       message_type: :outgoing, sender: agent,
                       created_at: Time.zone.parse('2026-08-11 09:00:00') + index.seconds)
    end

    template_conversation = create(:conversation, account: account)
    create(:message, account: account, conversation: template_conversation, inbox: template_conversation.inbox,
                     message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 09:30:00'),
                     additional_attributes: { 'template_params' => { 'name' => 'welcome' } })
    create(:message, account: account, conversation: template_conversation, inbox: template_conversation.inbox,
                     message_type: :outgoing, sender: agent, private: true, created_at: Time.zone.parse('2026-08-11 09:31:00'))
    create(:message, account: account, conversation: template_conversation, inbox: template_conversation.inbox,
                     message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 09:32:00'),
                     content_attributes: { 'automation_rule_id' => 1 })
    create(:message, account: account, conversation: template_conversation, inbox: template_conversation.inbox,
                     message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 09:33:00'),
                     additional_attributes: { 'campaign_id' => 1 })

    transfer_conversation = create(:conversation, account: account)
    create(:message, account: account, conversation: transfer_conversation, inbox: transfer_conversation.inbox,
                     message_type: :incoming, created_at: Time.zone.parse('2026-08-11 10:00:00'))
    create(:agent_assignment_interval, account: account, conversation: transfer_conversation, user: agent,
                                       started_at: Time.zone.parse('2026-08-11 10:05:00'))
    transfer_reply = create(:message, account: account, conversation: transfer_conversation, inbox: transfer_conversation.inbox,
                                      message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 10:06:00'))

    unassigned_conversation = create(:conversation, account: account)
    create(:message, account: account, conversation: unassigned_conversation, inbox: unassigned_conversation.inbox,
                     message_type: :incoming, created_at: Time.zone.parse('2026-08-11 11:00:00'))
    create(:agent_assignment_interval, account: account, conversation: unassigned_conversation, user: other_agent,
                                       started_at: Time.zone.parse('2026-08-11 11:00:00'))
    create(:message, account: account, conversation: unassigned_conversation, inbox: unassigned_conversation.inbox,
                     message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 11:01:00'))

    missing_history_conversation = create(:conversation, account: account)
    create(:message, account: account, conversation: missing_history_conversation, inbox: missing_history_conversation.inbox,
                     message_type: :incoming, created_at: Time.zone.parse('2026-08-11 11:30:00'))
    create(:message, account: account, conversation: missing_history_conversation, inbox: missing_history_conversation.inbox,
                     message_type: :outgoing, sender: agent, created_at: Time.zone.parse('2026-08-11 11:31:00'))

    { '12:00:00' => 180, '13:00:00' => 120 }.each do |reply_time, wait_seconds|
      conversation = create(:conversation, account: account)
      reply_at = Time.zone.parse("2026-08-11 #{reply_time}")
      create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                       message_type: :incoming, created_at: reply_at - wait_seconds.seconds)
      create(:agent_assignment_interval, account: account, conversation: conversation, user: agent,
                                         started_at: reply_at - wait_seconds.seconds)
      create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                       message_type: :outgoing, sender: agent, created_at: reply_at)
    end

    AgentPerformance::MessageCollector.new(account: account).perform
    AgentPerformance::DailyRollupBuilder.new(account: account, user_id: agent.id, date: date).perform

    get "/api/v1/accounts/#{account.id}/agent_performance/daily",
        params: { agent_id: agent.id, date: date.iso8601 }, headers: headers, as: :json

    transfer_sample = AgentPerformance::ResponseSample.find_by!(source_message_id: transfer_reply.id)
    expect(transfer_sample).to have_attributes(customer_wait_seconds: 360, accountable_wait_seconds: 60)
    expect(AgentPerformance::MessageFact.where(account: account, user: agent).count).to eq(16)
    expect(AgentPerformance::ResponseSample.where(account: account, user: agent).count).to eq(16)
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'messages' => { 'manual' => 15, 'manual_template' => 1, 'total_customer_facing' => 16 },
      'replied_conversations' => 7
    )
    expect(response.parsed_body['response_eligibility']).to include('eligible' => 4, 'excluded' => 12)
    expect(response.parsed_body['response_sla']).to include('met_count' => 4, 'compliance_percentage' => 100.0)
    expect(response.parsed_body['response_times']).to include(
      'average_seconds' => 105.0, 'median_seconds' => 90.0, 'p90_seconds' => 162.0
    )
  end
end
