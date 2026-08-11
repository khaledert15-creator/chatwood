class AgentPerformance::TargetResolver
  def initialize(account:, user_id:, period_type:, metric:, date:)
    @account = account
    @user_id = user_id
    @period_type = period_type
    @metric = metric
    @date = date
  end

  def resolve
    scoped_targets.find_by(user_id: user_id) || scoped_targets.find_by(user_id: nil)
  end

  private

  attr_reader :account, :user_id, :period_type, :metric, :date

  def scoped_targets
    account.agent_performance_targets.where(period_type: period_type, metric: metric).effective_on(date)
  end
end
