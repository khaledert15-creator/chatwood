require 'rails_helper'

RSpec.describe 'Agent performance targets API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account) }
  let(:headers) { admin.create_new_auth_token }

  before { account.enable_features!(:agent_performance_analytics) }

  it 'creates a daily SLA target with a configurable threshold' do
    post "/api/v1/accounts/#{account.id}/agent_performance/targets",
         params: {
           target: {
             user_id: agent.id, period_type: 'daily', metric: 'response_sla_compliance',
             target_value: 80, threshold_seconds: 180, effective_from: '2026-08-11'
           }
         }, headers: headers, as: :json

    expect(response).to have_http_status(:created)
    expect(AgentPerformance::Target.last).to have_attributes(target_value: 80, threshold_seconds: 180)
  end
end
