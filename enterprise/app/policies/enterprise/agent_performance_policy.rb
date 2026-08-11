module Enterprise::AgentPerformancePolicy
  def view?
    account_user.custom_role&.permissions&.include?('report_manage') || super
  end

  def manage_targets?
    account_user.custom_role&.permissions&.include?('report_manage') || super
  end
end
