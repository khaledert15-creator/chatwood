class AgentPerformance::MessageCollector
  COLLECTOR_NAME = 'messages'.freeze
  DEFAULT_BATCH_SIZE = 500

  def initialize(account:, batch_size: DEFAULT_BATCH_SIZE)
    @account = account
    @batch_size = batch_size
  end

  def perform
    return unless account.feature_enabled?('agent_performance_analytics')

    AgentPerformance::TrackingStart.ensure!(account)

    cursor.with_lock do
      messages = next_batch
      messages.each do |message|
        AgentPerformance::MessageFactProjector.call(message)
        AgentPerformance::ResponseSampleProjector.call(message)
      end
      update_cursor(messages)
      messages.size
    end
  rescue StandardError => e
    record_failure(e)
    raise
  end

  private

  attr_reader :account, :batch_size

  def cursor
    @cursor ||= AgentPerformance::AnalyticsCursor.find_or_create_by!(account: account, collector: COLLECTOR_NAME)
  end

  def next_batch
    account.messages.unscope(:order).where('messages.id > ?', cursor.last_source_id.to_i).order(:id).limit(batch_size)
  end

  def update_cursor(messages)
    last_message = messages.last
    cursor.update!(
      last_source_id: last_message&.id || cursor.last_source_id,
      last_source_timestamp: last_message&.created_at || cursor.last_source_timestamp,
      last_successful_run_at: Time.current,
      last_error_at: nil,
      last_error: nil
    )
  end

  def record_failure(error)
    cursor.update_columns(last_error_at: Time.current, last_error: error.message.to_s.truncate(255)) # rubocop:disable Rails/SkipsModelValidations
  rescue StandardError
    nil
  end
end
