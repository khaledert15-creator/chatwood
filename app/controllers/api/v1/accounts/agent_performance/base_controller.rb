class Api::V1::Accounts::AgentPerformance::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled

  private

  def ensure_feature_enabled
    head :not_found unless Current.account.feature_enabled?('agent_performance_analytics')
  end
end
