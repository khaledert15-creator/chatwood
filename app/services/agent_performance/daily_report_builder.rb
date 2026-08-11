class AgentPerformance::DailyReportBuilder
  TIMEZONE = 'Africa/Cairo'.freeze

  def initialize(account:, user:, date:)
    @account = account
    @user = user
    @date = date.to_date
  end

  def build
    {
      agent: { id: user.id, name: user.name, email: user.email },
      date: date, timezone: TIMEZONE,
      analytics_tracking_started_at: account.agent_performance_tracking_started_at,
      freshness: freshness,
      messages: messages,
      replied_conversations: rollup&.replied_conversations_count.to_i,
      response_times: response_times,
      response_sla: response_sla,
      response_distribution: response_distribution,
      response_eligibility: response_eligibility,
      targets: targets,
      hourly: hourly
    }
  end

  private

  attr_reader :account, :user, :date

  def rollup
    @rollup ||= AgentPerformance::DailyRollup.find_by(account_id: account.id, user_id: user.id, date: date)
  end

  def messages
    {
      manual: rollup&.manual_messages_count.to_i,
      manual_template: rollup&.manual_template_messages_count.to_i,
      total_customer_facing: rollup&.total_customer_facing_messages_count.to_i
    }
  end

  def response_times
    {
      average_seconds: rollup&.response_time_average_seconds,
      median_seconds: rollup&.response_time_median_seconds,
      p90_seconds: rollup&.response_time_p90_seconds,
      fastest_seconds: rollup&.response_time_fastest_seconds,
      slowest_seconds: rollup&.response_time_slowest_seconds,
      first_response_average_seconds: rollup&.first_response_time_average_seconds
    }
  end

  def response_sla
    eligible = rollup&.sla_eligible_count.to_i
    {
      threshold_seconds: rollup&.sla_threshold_seconds,
      eligible_count: eligible,
      met_count: rollup&.sla_met_count.to_i,
      compliance_percentage: eligible.zero? || rollup&.sla_threshold_seconds.blank? ? nil : (rollup.sla_met_count.to_f / eligible * 100).round(2)
    }
  end

  def response_distribution
    %i[bucket_under_1m bucket_1_to_3m bucket_3_to_5m bucket_5_to_10m bucket_10_to_30m bucket_30m_plus]
      .index_with { |key| rollup&.public_send(key).to_i }
  end

  def response_eligibility
    {
      eligible: rollup&.sla_eligible_count.to_i,
      excluded: rollup&.excluded_responses_count.to_i,
      exclusion_reasons: {
        assignment_history_missing: rollup&.excluded_assignment_history_missing_count.to_i,
        unassigned_responder: rollup&.excluded_unassigned_responder_count.to_i,
        invalid_waiting_episode: rollup&.excluded_invalid_waiting_episode_count.to_i
      }
    }
  end

  def targets
    {
      messages: evaluate_target('customer_facing_messages', messages[:total_customer_facing]),
      replied_conversations: evaluate_target('replied_conversations', rollup&.replied_conversations_count.to_i),
      response_sla: evaluate_target('response_sla_compliance', response_sla[:compliance_percentage], unit: :percentage)
    }
  end

  def evaluate_target(metric, actual, unit: :count)
    target = AgentPerformance::TargetResolver.new(
      account: account, user_id: user.id, period_type: 'daily', metric: metric, date: date
    ).resolve
    AgentPerformance::TargetEvaluator.new(target: target, actual: actual, unit: unit).as_json
  end

  def hourly
    AgentPerformance::HourlyRollup.where(account_id: account.id, user_id: user.id, hour: cairo_range).order(:hour).map do |row|
      { hour: row.hour, messages: row.total_customer_facing_messages_count, replied_conversations: row.replied_conversations_count }
    end
  end

  def cairo_range
    start = ActiveSupport::TimeZone[TIMEZONE].local(date.year, date.month, date.day)
    start...start.next_day
  end

  def freshness
    cursor = AgentPerformance::AnalyticsCursor.find_by(account_id: account.id, collector: AgentPerformance::MessageCollector::COLLECTOR_NAME)
    data_fresh_as_of = [cursor&.last_successful_run_at, rollup&.calculated_at].compact.min
    lag = (Time.current - data_fresh_as_of).to_i if data_fresh_as_of
    { data_fresh_as_of: data_fresh_as_of, analytics_lag_seconds: lag, delayed: lag.nil? || lag > 300 }
  end
end
