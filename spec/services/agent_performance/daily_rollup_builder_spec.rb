require 'rails_helper'

RSpec.describe AgentPerformance::DailyRollupBuilder do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:date) { Date.new(2026, 8, 11) }

  it 'counts the exact SLA threshold as compliant and calculates percentiles from eligible samples' do
    create(:agent_performance_target, account: account, user: agent, created_by: agent,
                                      metric: 'response_sla_compliance', target_value: 80,
                                      threshold_seconds: 180, effective_from: date)
    [60, 180, 300].each_with_index do |seconds, index|
      create(:agent_response_sample, account: account, user: agent, source_message_id: index + 1,
                                     responded_at: Time.zone.parse("2026-08-11 10:0#{index}:00"),
                                     accountable_wait_seconds: seconds)
    end

    described_class.new(account: account, user_id: agent.id, date: date).perform
    rollup = AgentPerformance::DailyRollup.find_by!(account: account, user: agent, date: date)

    expect(rollup).to have_attributes(sla_eligible_count: 3, sla_met_count: 2, response_time_median_seconds: 180.0)
  end

  it 'keeps zero eligible responses distinct from zero percent compliance' do
    described_class.new(account: account, user_id: agent.id, date: date).perform

    report = AgentPerformance::DailyReportBuilder.new(account: account, user: agent, date: date).build
    expect(report.dig(:response_sla, :compliance_percentage)).to be_nil
  end
end
