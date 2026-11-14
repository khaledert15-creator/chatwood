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
      chats: { customer: chat_counts.values.sum { |row| row[:customer] }, replied: chat_counts.values.sum { |row| row[:replied] } },
      agents: account.users.order(:name).map { |user| agent_row(user, rollups[user.id]) }
    }
  end

  private

  attr_reader :account, :date

  def rollups
    @rollups ||= AgentPerformance::DailyRollup.where(account_id: account.id, date: date).index_by(&:user_id)
  end

  def range
    start = ActiveSupport::TimeZone[TIMEZONE].local(date.year, date.month, date.day)
    start...start.next_day
  end

  # Conversations where a customer wrote on this day, grouped by current assignee. A conversation counts as replied
  # once an agent answered after the customer's last message of the day, even if the answer came the next day.
  def chat_counts
    @chat_counts ||= Conversation.joins("JOIN (#{last_customer_messages.to_sql}) last_customer ON last_customer.conversation_id = conversations.id")
                                 .group(:assignee_id)
                                 .pluck(:assignee_id, Arel.sql('COUNT(*)'), Arel.sql("COUNT(*) FILTER (WHERE EXISTS (#{agent_replies.to_sql}))"))
                                 .to_h { |assignee_id, customer, replied| [assignee_id, { customer: customer, replied: replied }] }
  end

  def last_customer_messages
    account.messages.unscope(:order).incoming.where(private: false, created_at: range)
           .group(:conversation_id).select('conversation_id, MAX(created_at) AS last_customer_at')
  end

  # Same rule as MessageClassifier: a non-private message an agent wrote, not sent by an automation or a campaign.
  def agent_replies
    Message.unscope(:order).outgoing.where(private: false, sender_type: 'User').select(1)
           .where('messages.conversation_id = last_customer.conversation_id AND messages.created_at > last_customer.last_customer_at')
           .where("COALESCE(messages.content_attributes->>'automation_rule_id', '') = ''")
           .where("COALESCE(messages.additional_attributes->>'campaign_id', '') = ''")
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
      assigned_chats: chat_counts.fetch(user.id, { customer: 0, replied: 0 }),
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
