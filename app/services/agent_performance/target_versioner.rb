class AgentPerformance::TargetVersioner
  def initialize(account:, actor:, attributes:)
    @account = account
    @actor = actor
    @attributes = attributes.symbolize_keys
  end

  def create!
    AgentPerformance::Target.transaction do
      close_current_target
      account.agent_performance_targets.create!(attributes.merge(created_by: actor))
    end
  end

  private

  attr_reader :account, :actor, :attributes

  # A target set again on the day it started replaces it; an older one ends the day before the new one starts.
  def close_current_target
    effective_from = attributes[:effective_from].to_date
    current = account.agent_performance_targets.where(
      user_id: attributes[:user_id], period_type: attributes[:period_type], metric: attributes[:metric]
    ).effective_on(effective_from).first
    return if current.blank?

    current.effective_from >= effective_from ? current.destroy! : current.update!(effective_until: effective_from - 1.day)
  end
end
