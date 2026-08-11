FactoryBot.define do
  factory :agent_performance_daily_rollup, class: 'AgentPerformance::DailyRollup' do
    account
    user
    date { Date.current }
    calculated_at { Time.current }
  end

  factory :agent_performance_hourly_rollup, class: 'AgentPerformance::HourlyRollup' do
    account
    user
    hour { Time.current.beginning_of_hour }
    calculated_at { Time.current }
  end
end
