require 'rails_helper'

RSpec.describe 'Agent performance daily API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account) }
  let(:headers) { admin.create_new_auth_token }

  before { account.enable_features!(:agent_performance_analytics) }

  it 'returns one row per agent with the four daily numbers and targets' do
    create(:agent_performance_daily_rollup, account: account, user: agent, date: Date.new(2026, 8, 11),
                                            total_customer_facing_messages_count: 40, replied_conversations_count: 12,
                                            sla_eligible_count: 10, response_time_median_seconds: 95.4,
                                            bucket_10_to_30m: 2, bucket_30m_plus: 1)
    create(:agent_performance_target, account: account, user: agent, created_by: admin,
                                      metric: 'customer_facing_messages', target_value: 50, effective_from: Date.new(2026, 8, 1))

    get "/api/v1/accounts/#{account.id}/agent_performance/daily", params: { date: '2026-08-11' }, headers: headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['agents'].find { |row| row['id'] == agent.id }).to include(
      'messages' => 40, 'conversations' => 12, 'replies' => 10, 'typical_reply_seconds' => 95, 'late_replies' => 3,
      'targets' => { 'messages' => 50, 'conversations' => nil }
    )
  end

  it 'is hidden when the feature is disabled' do
    account.disable_features!(:agent_performance_analytics)

    get "/api/v1/accounts/#{account.id}/agent_performance/daily", params: { date: '2026-08-11' }, headers: headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects agents from viewing payroll reports' do
    get "/api/v1/accounts/#{account.id}/agent_performance/daily",
        params: { date: '2026-08-11' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
