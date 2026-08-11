class AgentPerformancePolicy < ApplicationPolicy
  def view?
    account_user.administrator?
  end

  def manage_targets?
    account_user.administrator?
  end
end

AgentPerformancePolicy.prepend_mod_with('AgentPerformancePolicy')
