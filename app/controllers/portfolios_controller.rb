class PortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [ :show, :edit, :update, :destroy, :ai_advisor ]
  before_action :authorize_user!, only: [ :show, :edit, :update, :destroy, :ai_advisor ]

  def index
    @portfolios = current_user.portfolios.order(created_at: :desc)
  end

  def show
    # @portfolio is set by before_action
  end

  def new
    @portfolio = current_user.portfolios.build
  end

  def create
    @portfolio = current_user.portfolios.build(portfolio_params)

    if @portfolio.save
      redirect_to @portfolio, notice: "Portfolio was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @portfolio is set by before_action
  end

  def update
    if @portfolio.update(portfolio_params)
      redirect_to @portfolio, notice: "Portfolio was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @portfolio.destroy
    redirect_to portfolios_url, notice: "Portfolio was successfully deleted."
  end

  def ai_advisor
    advisor = AI::PortfolioAdvisor.new(@portfolio)
    result = advisor.generate_recommendations

    if result[:success]
      render json: {
        success: true,
        analysis: result[:analysis],
        generated_at: result[:generated_at]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  private

  def set_portfolio
    @portfolio = Portfolio.find(params[:id])
  end

  def authorize_user!
    unless @portfolio.user == current_user
      redirect_to portfolios_path, alert: "You are not authorized to perform this action."
    end
  end

  def portfolio_params
    params.require(:portfolio).permit(:name, :description)
  end
end
