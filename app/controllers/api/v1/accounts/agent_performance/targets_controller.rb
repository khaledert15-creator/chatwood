class Api::V1::Accounts::AgentPerformance::TargetsController < Api::V1::Accounts::AgentPerformance::BaseController
  before_action :authorize_manage

  def index
    render json: Current.account.agent_performance_targets.order(:metric, effective_from: :desc)
  end

  def create
    target = create_version!
    render json: target, status: :created
  end

  def update
    existing = Current.account.agent_performance_targets.find(params[:id])
    target = AgentPerformance::TargetVersioner.new(
      account: Current.account, actor: Current.user,
      attributes: target_params.to_h.symbolize_keys.reverse_merge(
        user_id: existing.user_id, period_type: existing.period_type, metric: existing.metric
      )
    ).create!
    render json: target
  end

  private

  def create_version!
    AgentPerformance::TargetVersioner.new(
      account: Current.account, actor: Current.user, attributes: target_params.to_h
    ).create!
  end

  def target_params
    params.require(:target).permit(:user_id, :period_type, :metric, :target_value, :threshold_seconds, :effective_from)
  end

  def authorize_manage
    authorize :agent_performance, :manage_targets?
  end
end
