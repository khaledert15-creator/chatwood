class AgentPerformance::DailyRollupBuilder
  TIMEZONE = 'Africa/Cairo'.freeze

  def initialize(account:, user_id:, date:)
    @account = account
    @user_id = user_id
    @date = date.to_date
  end

  def perform
    AgentPerformance::DailyRollup.upsert(attributes, unique_by: :index_agent_performance_daily_unique) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  attr_reader :account, :user_id, :date

  def attributes # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    statistics = response_statistics
    {
      account_id: account.id, user_id: user_id, date: date,
      manual_messages_count: facts.where(message_kind: 'manual').count,
      manual_template_messages_count: facts.where(message_kind: 'manual_template').count,
      total_customer_facing_messages_count: facts.count,
      replied_conversations_count: facts.distinct.count(:conversation_id),
      response_samples_count: responses.count,
      response_time_sum_seconds: statistics[:sum], response_time_average_seconds: statistics[:average],
      response_time_median_seconds: statistics[:median], response_time_p90_seconds: statistics[:p90],
      response_time_fastest_seconds: statistics[:minimum], response_time_slowest_seconds: statistics[:maximum],
      first_response_samples_count: eligible_responses.where(first_response: true).count,
      first_response_time_average_seconds: eligible_responses.where(first_response: true).average(:accountable_wait_seconds),
      sla_eligible_count: eligible_responses.count, sla_met_count: sla_met_count, sla_threshold_seconds: sla_threshold,
      excluded_responses_count: responses.where(sla_eligible: false).count,
      excluded_assignment_history_missing_count: responses.where(exclusion_reason: 'assignment_history_missing').count,
      excluded_unassigned_responder_count: responses.where(exclusion_reason: 'unassigned_responder').count,
      excluded_invalid_waiting_episode_count: responses.where(exclusion_reason: 'invalid_waiting_episode').count,
      **bucket_counts,
      calculated_at: Time.current, source_high_watermark: source_high_watermark,
      created_at: Time.current, updated_at: Time.current
    }
  end

  def range
    @range ||= begin
      start = ActiveSupport::TimeZone[TIMEZONE].local(date.year, date.month, date.day)
      start...start.next_day
    end
  end

  def facts
    @facts ||= AgentPerformance::MessageFact.where(account_id: account.id, user_id: user_id, sent_at: range)
  end

  def responses
    @responses ||= AgentPerformance::ResponseSample.where(account_id: account.id, user_id: user_id, responded_at: range)
  end

  def eligible_responses
    responses.eligible
  end

  def response_statistics
    values = eligible_responses.pick(
      Arel.sql('COALESCE(SUM(accountable_wait_seconds), 0)'),
      Arel.sql('AVG(accountable_wait_seconds)'),
      Arel.sql('PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY accountable_wait_seconds)'),
      Arel.sql('PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY accountable_wait_seconds)'),
      Arel.sql('MIN(accountable_wait_seconds)'),
      Arel.sql('MAX(accountable_wait_seconds)')
    )
    %i[sum average median p90 minimum maximum].zip(values).to_h
  end

  def sla_target
    @sla_target ||= AgentPerformance::TargetResolver.new(
      account: account, user_id: user_id, period_type: 'daily', metric: 'response_sla_compliance', date: date
    ).resolve
  end

  def sla_threshold
    sla_target&.threshold_seconds
  end

  def sla_met_count
    return 0 if sla_threshold.blank?

    eligible_responses.where(accountable_wait_seconds: ..sla_threshold).count
  end

  def bucket_counts
    {
      bucket_under_1m: eligible_responses.where(accountable_wait_seconds: ...60).count,
      bucket_1_to_3m: eligible_responses.where(accountable_wait_seconds: 60..180).count,
      bucket_3_to_5m: eligible_responses.where(accountable_wait_seconds: 181..300).count,
      bucket_5_to_10m: eligible_responses.where(accountable_wait_seconds: 301..600).count,
      bucket_10_to_30m: eligible_responses.where(accountable_wait_seconds: 601...1800).count,
      bucket_30m_plus: eligible_responses.where(accountable_wait_seconds: 1800..).count
    }
  end

  def source_high_watermark
    [facts.maximum(:source_message_id), responses.maximum(:source_message_id)].compact.max
  end
end
