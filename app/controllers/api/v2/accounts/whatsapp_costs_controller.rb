class Api::V2::Accounts::WhatsappCostsController < Api::V1::Accounts::BaseController
  def index
    authorize :report, :view?
    report = Whatsapp::CostReportService.new(Current.account, month: params[:month], timezone: params[:timezone]).perform
    render json: report
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
