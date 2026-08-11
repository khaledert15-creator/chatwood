class AgentPerformance::AssignmentEventProcessor
  def initialize(account:, conversation_id:, previous_assignee_id:, current_assignee_id:, occurred_at:, source_event_id:) # rubocop:disable Metrics/ParameterLists
    @account = account
    @conversation_id = conversation_id
    @previous_assignee_id = previous_assignee_id
    @current_assignee_id = current_assignee_id
    @occurred_at = occurred_at
    @source_event_id = source_event_id
  end

  def perform
    return if processed?

    AgentPerformance::AssignmentInterval.transaction do
      close_previous_interval
      open_current_interval
      set_tracking_started_at
    end
  end

  private

  attr_reader :account, :conversation_id, :previous_assignee_id, :current_assignee_id, :occurred_at, :source_event_id

  def processed?
    AgentPerformance::AssignmentInterval.where(source_event_id: source_event_id)
                                        .or(AgentPerformance::AssignmentInterval.where(end_source_event_id: source_event_id)).exists?
  end

  def close_previous_interval
    return if previous_assignee_id.blank?

    interval = AgentPerformance::AssignmentInterval.lock.find_by(
      account_id: account.id,
      conversation_id: conversation_id,
      user_id: previous_assignee_id,
      ended_at: nil
    )
    interval&.update!(ended_at: occurred_at, end_source_event_id: source_event_id)
  end

  def open_current_interval
    return if current_assignee_id.blank?

    AgentPerformance::AssignmentInterval.create!(
      account_id: account.id,
      conversation_id: conversation_id,
      user_id: current_assignee_id,
      started_at: occurred_at,
      source_event_id: source_event_id
    )
  end

  def set_tracking_started_at
    AgentPerformance::TrackingStart.ensure!(account, occurred_at)
  end
end
