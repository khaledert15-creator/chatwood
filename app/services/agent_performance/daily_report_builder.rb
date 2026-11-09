class AgentPerformance::DailyReportBuilder
  TIMEZONE = 'Africa/Cairo'.freeze
  LATE_REPLY_MINUTES = 10

  def initialize(account:, date:)
    @account = account
    @date = date.to_date
  end

  def build
    {
      date: date,
      late_reply_minutes: LATE_REPLY_MINUTES,
      updated_at: rollups.values.map(&:calculated_at).min,
      agents: account.users.order(:name).map { |user| agent_row(user, rollups[user.id]) }
    }
  end

  private

  attr_reader :account, :date

  def rollups
    @rollups ||= AgentPerformance::DailyRollup.where(account_id: account.id, date: date).index_by(&:user_id)
  end

  # bucket_10_to_30m starts at 601 seconds, so the two buckets together are replies slower than 10 minutes.
  def agent_row(user, rollup)
    {
      id: user.id, name: user.name, thumbnail: user.avatar_url,
      messages: rollup&.total_customer_facing_messages_count.to_i,
      conversations: rollup&.replied_conversations_count.to_i,
      replies: rollup&.sla_eligible_count.to_i,
      typical_reply_seconds: rollup&.response_time_median_seconds&.round,
      late_replies: rollup&.bucket_10_to_30m.to_i + rollup&.bucket_30m_plus.to_i,
      targets: {
        messages: target_value(user, 'customer_facing_messages'),
        conversations: target_value(user, 'replied_conversations')
      }
    }
  end

  def target_value(user, metric)
    AgentPerformance::TargetResolver.new(
      account: account, user_id: user.id, period_type: 'daily', metric: metric, date: date
    ).resolve&.target_value&.to_i
  end
end
