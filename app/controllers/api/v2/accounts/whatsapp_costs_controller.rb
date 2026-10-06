class Api::V2::Accounts::WhatsappCostsController < Api::V1::Accounts::BaseController
  def index
    authorize :report, :view?
    report = Whatsapp::CostReportService.new(Current.account, month: params[:month], timezone: params[:timezone]).perform
    render json: report
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def paid_messages
    authorize :report, :view?
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?

    report = Whatsapp::CostReportService.new(Current.account, month: params[:month], timezone: params[:timezone])
    service = Whatsapp::PaidMessagesService.new(
      Current.account,
      report: report,
      classification: params[:classification],
      inbox_id: params[:inbox_id],
      before_id: params[:before_id]
    )
    render json: service.perform
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
