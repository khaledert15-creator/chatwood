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

  def close_current_target
    current = account.agent_performance_targets.where(
      user_id: attributes[:user_id], period_type: attributes[:period_type], metric: attributes[:metric]
    ).effective_on(attributes[:effective_from]).first
    current&.update!(effective_until: attributes[:effective_from] - 1.day)
  end
end
