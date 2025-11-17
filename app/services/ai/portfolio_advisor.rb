# AI-powered portfolio analysis and recommendation service
module AI
  class PortfolioAdvisor
    def initialize(portfolio)
      @portfolio = portfolio
      @client = Anthropic::Client.new(api_key: ENV['ANTHROPIC_API_KEY'])
    end

    def generate_recommendations
      return { error: "API key not configured" } unless ENV['ANTHROPIC_API_KEY'].present?

      portfolio_data = prepare_portfolio_data
      market_data = prepare_market_data

      prompt = build_analysis_prompt(portfolio_data, market_data)

      begin
        response = @client.messages(
          model: "claude-3-5-sonnet-20241022",
          max_tokens: 2000,
          messages: [
            {
              role: "user",
              content: prompt
            }
          ]
        )

        {
          success: true,
          analysis: response.dig("content", 0, "text"),
          generated_at: Time.current
        }
      rescue => e
        Rails.logger.error "AI Portfolio Advisor Error: #{e.message}"
        {
          success: false,
          error: "Failed to generate recommendations: #{e.message}"
        }
      end
    end

    private

    def prepare_portfolio_data
      positions = @portfolio.positions.includes(:asset).map do |position|
        latest_price = position.asset.price_histories.order(date: :desc).first
        current_value = latest_price ? position.quantity * latest_price.close : nil
        cost_basis = position.quantity * position.average_cost
        gain_loss = current_value && cost_basis ? current_value - cost_basis : nil
        gain_loss_pct = gain_loss && cost_basis > 0 ? (gain_loss / cost_basis * 100).round(2) : nil

        {
          asset_name: position.asset.name,
          asset_type: position.asset.asset_class,
          symbol: position.asset.symbol,
          quantity: position.quantity,
          average_cost: position.average_cost,
          currency: position.asset.currency,
          purchase_date: position.purchase_date,
          cost_basis: cost_basis.round(2),
          current_value: current_value&.round(2),
          gain_loss: gain_loss&.round(2),
          gain_loss_percentage: gain_loss_pct,
          days_held: (Date.today - position.purchase_date).to_i
        }
      end

      total_value = @portfolio.positions.sum do |position|
        latest_price = position.asset.price_histories.order(date: :desc).first
        latest_price ? position.quantity * latest_price.close : 0
      end

      total_cost = @portfolio.positions.sum { |p| p.quantity * p.average_cost }
      total_gain_loss = total_value - total_cost
      total_gain_loss_pct = total_cost > 0 ? (total_gain_loss / total_cost * 100).round(2) : 0

      {
        name: @portfolio.name,
        total_positions: positions.count,
        positions: positions,
        total_value: total_value.round(2),
        total_cost: total_cost.round(2),
        total_gain_loss: total_gain_loss.round(2),
        total_gain_loss_percentage: total_gain_loss_pct,
        currency: @portfolio.base_currency
      }
    end

    def prepare_market_data
      # Get recent price trends for assets in portfolio
      trends = @portfolio.positions.includes(:asset).map do |position|
        asset = position.asset
        recent_prices = asset.price_histories.order(date: :desc).limit(30)

        if recent_prices.count >= 2
          latest = recent_prices.first
          month_ago = recent_prices.last
          price_change = ((latest.close - month_ago.close) / month_ago.close * 100).round(2)

          {
            symbol: asset.symbol,
            asset_name: asset.name,
            latest_price: latest.close.round(2),
            price_change_30d: price_change,
            trend: price_change > 0 ? "up" : "down"
          }
        else
          {
            symbol: asset.symbol,
            asset_name: asset.name,
            note: "Insufficient data for trend analysis"
          }
        end
      end

      {
        trends: trends,
        analysis_date: Date.today
      }
    end

    def build_analysis_prompt(portfolio_data, market_data)
      <<~PROMPT
        You are an expert financial advisor analyzing an investment portfolio. Please provide personalized recommendations based on the following data.

        PORTFOLIO OVERVIEW:
        Portfolio Name: #{portfolio_data[:name]}
        Base Currency: #{portfolio_data[:currency]}
        Total Positions: #{portfolio_data[:total_positions]}
        Total Value: #{portfolio_data[:total_value]} #{portfolio_data[:currency]}
        Total Cost Basis: #{portfolio_data[:total_cost]} #{portfolio_data[:currency]}
        Overall Gain/Loss: #{portfolio_data[:total_gain_loss]} #{portfolio_data[:currency]} (#{portfolio_data[:total_gain_loss_percentage]}%)

        POSITIONS:
        #{format_positions(portfolio_data[:positions])}

        RECENT MARKET TRENDS (30-day):
        #{format_market_trends(market_data[:trends])}

        Please provide:

        1. **Portfolio Health Assessment**: Overall evaluation of the portfolio's performance and risk profile.

        2. **Diversification Analysis**: Comment on asset allocation and diversification across asset types, sectors, and currencies.

        3. **Position-Specific Insights**: Highlight any positions that deserve attention (strong performers, underperformers, high-risk holdings).

        4. **Actionable Recommendations**: Provide 3-5 specific, actionable recommendations to improve the portfolio.

        5. **Risk Factors**: Identify key risks and vulnerabilities in the current portfolio composition.

        6. **Market Opportunities**: Based on recent trends, suggest potential areas for consideration.

        Please format your response in clear sections with headers. Be specific, data-driven, and actionable. Keep the tone professional but accessible.
      PROMPT
    end

    def format_positions(positions)
      positions.map.with_index(1) do |pos, idx|
        status = if pos[:gain_loss_percentage]
                   pos[:gain_loss_percentage] > 0 ? "📈 +#{pos[:gain_loss_percentage]}%" : "📉 #{pos[:gain_loss_percentage]}%"
                 else
                   "⏳ No current value"
                 end

        <<~POSITION
          #{idx}. #{pos[:asset_name]} (#{pos[:symbol]}) - #{pos[:asset_type].upcase}
             - Quantity: #{pos[:quantity]}
             - Avg Cost: #{pos[:average_cost]} #{pos[:currency]}
             - Cost Basis: #{pos[:cost_basis]} #{pos[:currency]}
             - Current Value: #{pos[:current_value] || 'N/A'} #{pos[:currency]}
             - Gain/Loss: #{pos[:gain_loss] || 'N/A'} #{pos[:currency]} #{status}
             - Holding Period: #{pos[:days_held]} days
             - Purchase Date: #{pos[:purchase_date]}
        POSITION
      end.join("\n")
    end

    def format_market_trends(trends)
      trends.map do |trend|
        if trend[:note]
          "- #{trend[:asset_name]} (#{trend[:symbol]}): #{trend[:note]}"
        else
          direction = trend[:price_change_30d] > 0 ? "📈" : "📉"
          "- #{trend[:asset_name]} (#{trend[:symbol]}): #{direction} #{trend[:price_change_30d]}% over 30 days (Latest: #{trend[:latest_price]})"
        end
      end.join("\n")
    end
  end
end
