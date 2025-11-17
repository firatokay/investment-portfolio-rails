# AI Portfolio Advisor

This application includes an AI-powered portfolio advisor that provides personalized investment recommendations using Claude AI.

## Overview

The AI Portfolio Advisor analyzes your investment portfolio and provides:

1. **Portfolio Health Assessment** - Overall evaluation of performance and risk
2. **Diversification Analysis** - Assessment of asset allocation across types, sectors, and currencies
3. **Position-Specific Insights** - Highlights on individual positions that deserve attention
4. **Actionable Recommendations** - 3-5 specific suggestions to improve your portfolio
5. **Risk Factors** - Key vulnerabilities in your current holdings
6. **Market Opportunities** - Suggestions based on recent market trends

## Setup

### 1. Get an Anthropic API Key

1. Visit [Anthropic Console](https://console.anthropic.com/)
2. Sign up for an account (if you don't have one)
3. Navigate to API Keys section
4. Create a new API key
5. Copy your API key

### 2. Configure Environment Variable

Add your API key to your `.env` file:

```bash
ANTHROPIC_API_KEY=your_api_key_here
```

**Important**: Never commit your `.env` file to version control. The `.env.example` file is provided as a template.

### 3. Install Dependencies

The `anthropic` gem is included in the Gemfile. Run:

```bash
bundle install
```

## Usage

### Accessing the AI Advisor

1. Navigate to any portfolio with at least one position
2. Click the "AI Advisor" button (purple gradient button with lightbulb icon)
3. Wait a few seconds while the AI analyzes your portfolio
4. Review the personalized recommendations

### What Data is Analyzed

The AI Advisor analyzes:

- **Portfolio composition**: All positions, asset types, and allocations
- **Performance metrics**: Gain/loss for each position and overall
- **Market trends**: 30-day price movements for your assets
- **Holding periods**: How long you've held each position
- **Diversification**: Distribution across asset classes and currencies

### Sample Analysis Sections

The AI provides structured analysis including:

```
1. Portfolio Health Assessment
   Overall evaluation of the portfolio's performance and risk profile

2. Diversification Analysis
   Commentary on asset allocation across different categories

3. Position-Specific Insights
   Highlights of strong performers, underperformers, and high-risk holdings

4. Actionable Recommendations
   Specific steps you can take to improve your portfolio

5. Risk Factors
   Key risks and vulnerabilities to be aware of

6. Market Opportunities
   Potential areas for consideration based on trends
```

## Features

### Real-Time Analysis

- Analysis is generated fresh each time you click the button
- Uses latest market data and position values
- Reflects current trends (30-day price movements)

### User-Friendly Interface

- Beautiful modal dialog with loading animation
- Markdown-formatted analysis for readability
- Timestamps to track when analysis was generated
- Disclaimer about informational use only

### Error Handling

The system gracefully handles:

- Missing API key (shows configuration error)
- Network issues (shows connection error)
- API rate limits (shows service unavailable message)

## API Usage and Costs

### Claude AI Model

- Model: `claude-3-5-sonnet-20241022`
- Max tokens per request: 2000 tokens
- Typical response: 1000-1500 tokens

### Cost Estimation

Based on Anthropic's pricing (as of 2024):

- Input: ~$3 per million tokens
- Output: ~$15 per million tokens
- Typical analysis cost: ~$0.02-0.03 per request

**Recommendation**: For personal use, the cost is negligible. For production applications with many users, consider implementing:
- Rate limiting per user
- Caching analyses (e.g., once per day)
- Monthly usage caps

## Technical Details

### Service Architecture

```
User clicks "AI Advisor" button
         ↓
JavaScript fetches /portfolios/:id/ai_advisor
         ↓
PortfoliosController#ai_advisor
         ↓
AI::PortfolioAdvisor service
         ↓
Anthropic API call
         ↓
Format and return analysis
         ↓
Display in modal
```

### Key Files

1. **Service**: `app/services/ai/portfolio_advisor.rb`
   - Prepares portfolio data
   - Analyzes market trends
   - Calls Anthropic API
   - Formats prompt

2. **Controller**: `app/controllers/portfolios_controller.rb`
   - `ai_advisor` action handles requests
   - Returns JSON response

3. **View**: `app/views/portfolios/show.html.erb`
   - AI Advisor button
   - Modal dialog
   - JavaScript for API calls
   - Markdown formatting

4. **Route**: `config/routes.rb`
   - `POST /portfolios/:id/ai_advisor`

## Privacy and Security

### Data Sent to Anthropic

The following data is sent to Claude AI for analysis:

- Portfolio name and currency
- Position details (symbols, quantities, costs, values)
- Recent price trends (30-day)
- Calculated metrics (gains/losses, percentages)

**What is NOT sent:**
- User personal information
- Account credentials
- Email addresses
- Payment information

### API Key Security

- Store API key in environment variables only
- Never commit `.env` to version control
- Use `.env.example` as template
- Rotate keys regularly
- Monitor API usage in Anthropic Console

## Limitations

### What the AI Can Do

- Analyze portfolio composition
- Identify diversification issues
- Highlight performance outliers
- Suggest general investment principles
- Assess risk based on available data

### What the AI Cannot Do

- Predict future market movements
- Guarantee investment returns
- Replace professional financial advice
- Access real-time news or events
- Make trades on your behalf
- Provide tax or legal advice

### Disclaimer

**IMPORTANT**: The AI Portfolio Advisor is for informational purposes only. It should not be considered professional financial advice. Always:

- Consult with a qualified financial advisor before making investment decisions
- Do your own research
- Understand the risks involved in investing
- Consider your personal financial situation and goals

## Troubleshooting

### "API key not configured" Error

**Problem**: ANTHROPIC_API_KEY environment variable is not set

**Solution**:
1. Check `.env` file exists
2. Verify API key is set: `ANTHROPIC_API_KEY=sk-ant-...`
3. Restart Rails server after adding the key

### "Failed to generate recommendations" Error

**Possible causes**:
1. Invalid API key
2. API rate limit exceeded
3. Network connectivity issues
4. Anthropic API service outage

**Solutions**:
1. Verify API key in [Anthropic Console](https://console.anthropic.com/)
2. Check rate limits and upgrade plan if needed
3. Test internet connection
4. Check [Anthropic Status Page](https://status.anthropic.com/)

### Analysis Takes Too Long

**Normal behavior**:
- Typical response time: 3-10 seconds
- Depends on portfolio complexity
- Network latency affects speed

**If exceeding 30 seconds**:
1. Check internet connection
2. Verify Anthropic API status
3. Review Rails logs for errors: `tail -f log/development.log`

### Empty or Generic Recommendations

**Causes**:
- Portfolio has no or very few positions
- Missing price history data
- Insufficient market data

**Solutions**:
1. Ensure portfolio has multiple positions
2. Run market data updates: `rails market_data:update_all`
3. Wait for price history to accumulate (30 days recommended)

## Future Enhancements

Potential improvements:

1. **Caching**: Store analysis for 24 hours to reduce API calls
2. **Comparison**: Compare portfolio against benchmarks (S&P 500, etc.)
3. **Alerts**: Automated weekly/monthly recommendations via email
4. **Historical Tracking**: Save analyses to track advice over time
5. **Custom Prompts**: Let users ask specific questions
6. **Multi-Language**: Support for different languages
7. **Export**: Download analysis as PDF
8. **Visualization**: Charts showing diversification and risk

## Support

For issues or questions:

1. Check this documentation first
2. Review [Anthropic API Documentation](https://docs.anthropic.com/)
3. Check Rails logs for detailed error messages
4. Verify all environment variables are set correctly

## Version History

- **v1.0** (November 2025)
  - Initial release
  - Claude 3.5 Sonnet integration
  - Basic portfolio analysis
  - Markdown-formatted recommendations
