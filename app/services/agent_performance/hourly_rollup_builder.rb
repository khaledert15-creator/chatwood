class AgentPerformance::HourlyRollupBuilder
  def initialize(account:, user_id:, hour:)
    @account = account
    @user_id = user_id
    @hour = hour.beginning_of_hour
  end

  def perform
    AgentPerformance::HourlyRollup.upsert(attributes, unique_by: :index_agent_performance_hourly_unique) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  attr_reader :account, :user_id, :hour

  def attributes # rubocop:disable Metrics/AbcSize
    response_count = eligible_responses.count
    response_sum = eligible_responses.sum(:accountable_wait_seconds)
    {
      account_id: account.id, user_id: user_id, hour: hour,
      manual_messages_count: facts.where(message_kind: 'manual').count,
      manual_template_messages_count: facts.where(message_kind: 'manual_template').count,
      total_customer_facing_messages_count: facts.count,
      replied_conversations_count: facts.distinct.count(:conversation_id), response_samples_count: responses.count,
      response_time_sum_seconds: response_sum,
      response_time_average_seconds: response_count.zero? ? nil : response_sum.to_f / response_count,
      sla_eligible_count: response_count, sla_met_count: 0,
      calculated_at: Time.current, created_at: Time.current, updated_at: Time.current
    }
  end

  def range
    hour...hour + 1.hour
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
end
