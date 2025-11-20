require 'rails_helper'
require 'webmock/rspec'

RSpec.describe "Portfolios", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user, email: 'other@example.com') }
  let(:portfolio) { create(:portfolio, user: user) }
  let(:other_portfolio) { create(:portfolio, user: other_user) }

  before do
    # Stub ForexDataService to prevent real API calls in ensure_fresh_exchange_rates
    allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate)
  end

  describe "GET /portfolios" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get portfolios_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "returns http success" do
        get portfolios_path
        expect(response).to have_http_status(:success)
      end

      it "displays user's portfolios" do
        portfolio # Create the portfolio
        get portfolios_path
        expect(response.body).to include(portfolio.name)
      end

      it "does not display other users' portfolios" do
        other_portfolio # Create other user's portfolio
        get portfolios_path
        expect(response.body).not_to include(other_portfolio.name)
      end

      it "orders portfolios by created_at desc" do
        old_portfolio = create(:portfolio, user: user, name: "Old Portfolio", created_at: 2.days.ago)
        new_portfolio = create(:portfolio, user: user, name: "New Portfolio", created_at: 1.day.ago)

        get portfolios_path

        # Check that new portfolio appears before old portfolio in the response
        new_pos = response.body.index("New Portfolio")
        old_pos = response.body.index("Old Portfolio")
        expect(new_pos).to be < old_pos
      end
    end
  end

  describe "GET /portfolios/:id" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get portfolio_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "returns http success for own portfolio" do
        get portfolio_path(portfolio)
        expect(response).to have_http_status(:success)
      end

      it "displays portfolio details" do
        get portfolio_path(portfolio)
        expect(response.body).to include(portfolio.name)
        expect(response.body).to include(portfolio.description) if portfolio.description.present?
      end

      it "redirects when trying to view other user's portfolio" do
        get portfolio_path(other_portfolio)
        expect(response).to redirect_to(portfolios_path)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end

      context "with stale exchange rates" do
        let!(:old_usd_rate) do
          create(:currency_rate,
            from_currency: 'USD',
            to_currency: 'TRY',
            rate: 32.0,
            date: 2.days.ago
          )
        end

        let!(:old_eur_rate) do
          create(:currency_rate,
            from_currency: 'EUR',
            to_currency: 'TRY',
            rate: 45.0,
            date: 2.days.ago
          )
        end

        it "fetches fresh exchange rates when viewing portfolio" do
          # Mock the forex service to return new rates
          allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate) do |service, args|
            create(:currency_rate,
              from_currency: args[:from_currency],
              to_currency: args[:to_currency],
              rate: args[:from_currency] == 'USD' ? 35.0 : 48.5,
              date: Date.today
            )
          end

          expect {
            get portfolio_path(portfolio)
          }.to change {
            CurrencyRate.where(date: Date.today).count
          }.by(2) # USD/TRY and EUR/TRY

          expect(response).to have_http_status(:success)
        end

        it "handles API errors gracefully" do
          allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate)
            .and_raise(MarketData::TwelveDataProvider::ApiError.new('API error'))

          expect {
            get portfolio_path(portfolio)
          }.not_to raise_error

          expect(response).to have_http_status(:success)
        end
      end

      context "with fresh exchange rates" do
        let!(:today_usd_rate) do
          create(:currency_rate,
            from_currency: 'USD',
            to_currency: 'TRY',
            rate: 35.0,
            date: Date.today
          )
        end

        let!(:today_eur_rate) do
          create(:currency_rate,
            from_currency: 'EUR',
            to_currency: 'TRY',
            rate: 48.5,
            date: Date.today
          )
        end

        it "does not fetch new rates when rates are current" do
          expect_any_instance_of(MarketData::ForexDataService).not_to receive(:update_currency_rate)

          get portfolio_path(portfolio)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /portfolios/new" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get new_portfolio_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "returns http success" do
        get new_portfolio_path
        expect(response).to have_http_status(:success)
      end

      it "displays the form" do
        get new_portfolio_path
        expect(response.body).to include('form')
        expect(response.body).to include('Name')
      end
    end
  end

  describe "POST /portfolios" do
    context "when user is not logged in" do
      it "redirects to login page" do
        post portfolios_path, params: { portfolio: { name: "Test Portfolio" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      context "with valid params" do
        let(:valid_params) do
          { portfolio: { name: "My New Portfolio", description: "A test portfolio" } }
        end

        it "creates a new portfolio" do
          expect {
            post portfolios_path, params: valid_params
          }.to change(Portfolio, :count).by(1)
        end

        it "associates portfolio with current user" do
          post portfolios_path, params: valid_params
          expect(Portfolio.last.user).to eq(user)
        end

        it "redirects to the portfolio show page" do
          post portfolios_path, params: valid_params
          expect(response).to redirect_to(portfolio_path(Portfolio.last))
        end

        it "sets a success notice" do
          post portfolios_path, params: valid_params
          follow_redirect!
          expect(response.body).to include("successfully created")
        end
      end

      context "with invalid params" do
        let(:invalid_params) do
          { portfolio: { name: "" } }
        end

        it "does not create a new portfolio" do
          expect {
            post portfolios_path, params: invalid_params
          }.not_to change(Portfolio, :count)
        end

        it "returns unprocessable entity status" do
          post portfolios_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders the new template" do
          post portfolios_path, params: invalid_params
          expect(response.body).to include('form')
        end
      end
    end
  end

  describe "GET /portfolios/:id/edit" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get edit_portfolio_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "returns http success for own portfolio" do
        get edit_portfolio_path(portfolio)
        expect(response).to have_http_status(:success)
      end

      it "displays the edit form" do
        get edit_portfolio_path(portfolio)
        expect(response.body).to include('form')
        expect(response.body).to include(portfolio.name)
      end

      it "redirects when trying to edit other user's portfolio" do
        get edit_portfolio_path(other_portfolio)
        expect(response).to redirect_to(portfolios_path)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end
    end
  end

  describe "PATCH /portfolios/:id" do
    context "when user is not logged in" do
      it "redirects to login page" do
        patch portfolio_path(portfolio), params: { portfolio: { name: "Updated" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      context "with valid params" do
        let(:new_attributes) do
          { portfolio: { name: "Updated Portfolio Name", description: "Updated description" } }
        end

        it "updates the portfolio" do
          patch portfolio_path(portfolio), params: new_attributes
          portfolio.reload
          expect(portfolio.name).to eq("Updated Portfolio Name")
          expect(portfolio.description).to eq("Updated description")
        end

        it "redirects to the portfolio show page" do
          patch portfolio_path(portfolio), params: new_attributes
          expect(response).to redirect_to(portfolio_path(portfolio))
        end

        it "sets a success notice" do
          patch portfolio_path(portfolio), params: new_attributes
          follow_redirect!
          expect(response.body).to include("successfully updated")
        end
      end

      context "with invalid params" do
        let(:invalid_attributes) do
          { portfolio: { name: "" } }
        end

        it "does not update the portfolio" do
          original_name = portfolio.name
          patch portfolio_path(portfolio), params: invalid_attributes
          portfolio.reload
          expect(portfolio.name).to eq(original_name)
        end

        it "returns unprocessable entity status" do
          patch portfolio_path(portfolio), params: invalid_attributes
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders the edit template" do
          patch portfolio_path(portfolio), params: invalid_attributes
          expect(response.body).to include('form')
        end
      end

      it "redirects when trying to update other user's portfolio" do
        patch portfolio_path(other_portfolio), params: { portfolio: { name: "Hacked" } }
        expect(response).to redirect_to(portfolios_path)
        other_portfolio.reload
        expect(other_portfolio.name).not_to eq("Hacked")
      end
    end
  end

  describe "DELETE /portfolios/:id" do
    context "when user is not logged in" do
      it "redirects to login page" do
        delete portfolio_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "destroys the portfolio" do
        portfolio_to_delete = create(:portfolio, user: user)
        expect {
          delete portfolio_path(portfolio_to_delete)
        }.to change(Portfolio, :count).by(-1)
      end

      it "redirects to portfolios list" do
        delete portfolio_path(portfolio)
        expect(response).to redirect_to(portfolios_url)
      end

      it "sets a success notice" do
        delete portfolio_path(portfolio)
        follow_redirect!
        expect(response.body).to include("successfully deleted")
      end

      it "does not allow deleting other user's portfolio" do
        other_portfolio_to_delete = create(:portfolio, user: other_user)

        expect {
          delete portfolio_path(other_portfolio_to_delete)
        }.not_to change(Portfolio, :count)

        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "POST /portfolios/:id/ai_advisor" do
    context "when user is not logged in" do
      it "redirects to login page" do
        post ai_advisor_portfolio_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      context "with successful AI generation" do
        before do
          allow_any_instance_of(AI::PortfolioAdvisor).to receive(:generate_recommendations).and_return({
            success: true,
            analysis: "Your portfolio is well diversified.",
            generated_at: Time.current
          })
        end

        it "returns http success" do
          post ai_advisor_portfolio_path(portfolio), as: :json
          expect(response).to have_http_status(:success)
        end

        it "returns JSON with analysis" do
          post ai_advisor_portfolio_path(portfolio), as: :json
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['analysis']).to eq("Your portfolio is well diversified.")
        end
      end

      context "with AI generation failure" do
        before do
          allow_any_instance_of(AI::PortfolioAdvisor).to receive(:generate_recommendations).and_return({
            success: false,
            error: "API key not configured"
          })
        end

        it "returns unprocessable entity status" do
          post ai_advisor_portfolio_path(portfolio), as: :json
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns JSON with error" do
          post ai_advisor_portfolio_path(portfolio), as: :json
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be false
          expect(json_response['error']).to eq("API key not configured")
        end
      end

      it "redirects when trying to access other user's portfolio advisor" do
        allow_any_instance_of(AI::PortfolioAdvisor).to receive(:generate_recommendations).and_return({
          success: true,
          analysis: "Test"
        })

        post ai_advisor_portfolio_path(other_portfolio), as: :json
        expect(response).to have_http_status(:found) # redirect status
      end
    end
  end
end
