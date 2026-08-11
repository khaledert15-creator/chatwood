class Api::V1::Accounts::AgentPerformance::DailyController < Api::V1::Accounts::AgentPerformance::BaseController
  before_action :authorize_view

  def show
    user = Current.account.users.find(params[:agent_id])
    date = params[:date].present? ? Date.iso8601(params[:date]) : Time.current.in_time_zone('Africa/Cairo').to_date
    render json: AgentPerformance::DailyReportBuilder.new(account: Current.account, user: user, date: date).build
  end

  private

  def authorize_view
    authorize :agent_performance, :view?
  end
end
