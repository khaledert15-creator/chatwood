require 'rails_helper'

RSpec.describe 'Agent performance daily API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account) }
  let(:headers) { admin.create_new_auth_token }

  before { account.enable_features!(:agent_performance_analytics) }

  it 'returns the daily report with freshness and eligibility details' do
    create(:agent_performance_daily_rollup, account: account, user: agent, date: Date.new(2026, 8, 11),
                                            calculated_at: Time.current, sla_eligible_count: 0,
                                            excluded_responses_count: 1,
                                            excluded_assignment_history_missing_count: 1)

    get "/api/v1/accounts/#{account.id}/agent_performance/daily",
        params: { agent_id: agent.id, date: '2026-08-11' }, headers: headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('response_sla', 'compliance_percentage')).to be_nil
    expect(response.parsed_body.dig('response_eligibility', 'excluded')).to eq(1)
  end

  it 'is hidden when the feature is disabled' do
    account.disable_features!(:agent_performance_analytics)

    get "/api/v1/accounts/#{account.id}/agent_performance/daily",
        params: { agent_id: agent.id, date: '2026-08-11' }, headers: headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects agents from viewing payroll reports' do
    get "/api/v1/accounts/#{account.id}/agent_performance/daily",
        params: { agent_id: agent.id, date: '2026-08-11' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
