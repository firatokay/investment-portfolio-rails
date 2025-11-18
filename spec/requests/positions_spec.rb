require 'rails_helper'

RSpec.describe "Positions", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user, email: 'other@example.com') }
  let(:portfolio) { create(:portfolio, user: user) }
  let(:other_portfolio) { create(:portfolio, user: other_user) }
  let(:asset) { create(:asset, symbol: 'THYAO', name: 'THY', asset_class: :stock, exchange: :bist, currency: 'TRY') }
  let(:position) do
    pos = build(:position, portfolio: portfolio, asset: asset, quantity: 100, average_cost: 200.0, purchase_currency: 'TRY')
    pos.save(validate: false)
    pos
  end

  describe "GET /portfolios/:portfolio_id/positions" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get portfolio_positions_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "loads the positions for the portfolio" do
        position # Create the position
        get portfolio_positions_path(portfolio)
        expect(assigns(:positions)).to include(position)
      end

      it "redirects when accessing other user's portfolio" do
        get portfolio_positions_path(other_portfolio)
        expect(response).to redirect_to(portfolios_path)
        follow_redirect!
        expect(response.body).to include("not authorized")
      end
    end
  end

  describe "GET /portfolios/:portfolio_id/positions/:id" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get portfolio_position_path(portfolio, position)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "loads the position and its transactions" do
        get portfolio_position_path(portfolio, position)
        expect(assigns(:position)).to eq(position)
        expect(assigns(:transactions)).to be_an(ActiveRecord::Relation)
      end

      it "redirects when accessing other user's position" do
        other_position = build(:position, portfolio: other_portfolio, asset: asset)
        other_position.save(validate: false)

        get portfolio_position_path(other_portfolio, other_position)
        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "GET /portfolios/:portfolio_id/positions/new" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get new_portfolio_position_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "returns http success" do
        get new_portfolio_position_path(portfolio)
        expect(response).to have_http_status(:success)
      end

      it "displays the form" do
        get new_portfolio_position_path(portfolio)
        expect(response.body).to include('form')
      end

      it "loads assets for selection" do
        asset # Create the asset
        get new_portfolio_position_path(portfolio)
        expect(assigns(:assets)).to include(asset)
      end

      it "redirects when accessing other user's portfolio" do
        get new_portfolio_position_path(other_portfolio)
        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "POST /portfolios/:portfolio_id/positions" do
    context "when user is not logged in" do
      it "redirects to login page" do
        post portfolio_positions_path(portfolio), params: {
          position: { asset_id: asset.id, quantity: 100, average_cost: 200 }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      context "with valid params" do
        let(:valid_params) do
          {
            position: {
              asset_id: asset.id,
              purchase_date: Date.today,
              quantity: 100,
              average_cost: 200.0,
              purchase_currency: 'TRY',
              notes: 'Test position'
            }
          }
        end

        it "creates a new position" do
          expect {
            post portfolio_positions_path(portfolio), params: valid_params
          }.to change(Position, :count).by(1)
        end

        it "associates position with the portfolio" do
          post portfolio_positions_path(portfolio), params: valid_params
          expect(Position.last.portfolio).to eq(portfolio)
        end

        it "redirects to the portfolio show page" do
          post portfolio_positions_path(portfolio), params: valid_params
          expect(response).to redirect_to(portfolio_path(portfolio))
        end

        it "sets a success notice" do
          post portfolio_positions_path(portfolio), params: valid_params
          follow_redirect!
          expect(response.body).to include("successfully created")
        end
      end

      context "with invalid params" do
        let(:invalid_params) do
          {
            position: {
              asset_id: asset.id,
              quantity: -10, # Invalid - negative quantity
              average_cost: 200.0
            }
          }
        end

        it "does not create a new position" do
          expect {
            post portfolio_positions_path(portfolio), params: invalid_params
          }.not_to change(Position, :count)
        end

        it "returns unprocessable entity status" do
          post portfolio_positions_path(portfolio), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders the new template" do
          post portfolio_positions_path(portfolio), params: invalid_params
          expect(response.body).to include('form')
        end
      end

      it "cannot create position in other user's portfolio" do
        expect {
          post portfolio_positions_path(other_portfolio), params: {
            position: { asset_id: asset.id, quantity: 100, average_cost: 200 }
          }
        }.not_to change(Position, :count)

        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "GET /portfolios/:portfolio_id/positions/:id/edit" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get edit_portfolio_position_path(portfolio, position)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "returns http success" do
        get edit_portfolio_position_path(portfolio, position)
        expect(response).to have_http_status(:success)
      end

      it "displays the edit form" do
        get edit_portfolio_position_path(portfolio, position)
        expect(response.body).to include('form')
        expect(response.body).to include(position.quantity.to_s)
      end

      it "redirects when accessing other user's position" do
        other_position = build(:position, portfolio: other_portfolio, asset: asset)
        other_position.save(validate: false)

        get edit_portfolio_position_path(other_portfolio, other_position)
        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "PATCH /portfolios/:portfolio_id/positions/:id" do
    context "when user is not logged in" do
      it "redirects to login page" do
        patch portfolio_position_path(portfolio, position), params: {
          position: { quantity: 150 }
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      context "with valid params" do
        let(:new_attributes) do
          { position: { quantity: 150, average_cost: 220.0, notes: 'Updated notes' } }
        end

        it "updates the position" do
          patch portfolio_position_path(portfolio, position), params: new_attributes
          position.reload
          expect(position.quantity).to eq(150)
          expect(position.average_cost).to eq(220.0)
        end

        it "redirects to the portfolio show page" do
          patch portfolio_position_path(portfolio, position), params: new_attributes
          expect(response).to redirect_to(portfolio_path(portfolio))
        end

        it "sets a success notice" do
          patch portfolio_position_path(portfolio, position), params: new_attributes
          follow_redirect!
          expect(response.body).to include("successfully updated")
        end
      end

      context "with invalid params" do
        let(:invalid_attributes) do
          { position: { quantity: -10 } }
        end

        it "does not update the position" do
          original_quantity = position.quantity
          patch portfolio_position_path(portfolio, position), params: invalid_attributes
          position.reload
          expect(position.quantity).to eq(original_quantity)
        end

        it "returns unprocessable entity status" do
          patch portfolio_position_path(portfolio, position), params: invalid_attributes
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      it "cannot update other user's position" do
        other_position = build(:position, portfolio: other_portfolio, asset: asset, quantity: 50)
        other_position.save(validate: false)

        patch portfolio_position_path(other_portfolio, other_position), params: {
          position: { quantity: 999 }
        }

        expect(response).to redirect_to(portfolios_path)
        other_position.reload
        expect(other_position.quantity).to eq(50)
      end
    end
  end

  describe "DELETE /portfolios/:portfolio_id/positions/:id" do
    context "when user is not logged in" do
      it "redirects to login page" do
        delete portfolio_position_path(portfolio, position)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      it "destroys the position" do
        position_to_delete = build(:position, portfolio: portfolio, asset: asset)
        position_to_delete.save(validate: false)

        expect {
          delete portfolio_position_path(portfolio, position_to_delete)
        }.to change(Position, :count).by(-1)
      end

      it "redirects to portfolio show page" do
        delete portfolio_position_path(portfolio, position)
        expect(response).to redirect_to(portfolio_path(portfolio))
      end

      it "sets a success notice" do
        delete portfolio_position_path(portfolio, position)
        follow_redirect!
        expect(response.body).to include("successfully deleted")
      end

      it "cannot delete other user's position" do
        other_position = build(:position, portfolio: other_portfolio, asset: asset)
        other_position.save(validate: false)

        expect {
          delete portfolio_position_path(other_portfolio, other_position)
        }.not_to change(Position, :count)

        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "GET /portfolios/:portfolio_id/positions/:id/progress" do
    let!(:price_history1) { create(:price_history, asset: asset, date: 10.days.ago, close: 180.0) }
    let!(:price_history2) { create(:price_history, asset: asset, date: 5.days.ago, close: 190.0) }
    let!(:price_history3) { create(:price_history, asset: asset, date: Date.today, close: 200.0) }

    context "when user is not logged in" do
      it "redirects to login page" do
        get progress_portfolio_position_path(portfolio, position)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before do
        sign_in user
        position.update_column(:purchase_date, 15.days.ago)
      end

      it "returns http success for HTML" do
        get progress_portfolio_position_path(portfolio, position)
        expect(response).to have_http_status(:success)
      end

      it "returns JSON data" do
        get progress_portfolio_position_path(portfolio, position), as: :json
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['position']).to be_present
        expect(json_response['data_points']).to be_an(Array)
      end

      it "includes position details in JSON" do
        get progress_portfolio_position_path(portfolio, position), as: :json
        json_response = JSON.parse(response.body)
        expect(json_response['position']['asset_symbol']).to eq(asset.symbol)
        expect(json_response['position']['quantity'].to_f).to eq(position.quantity.to_f)
      end

      it "redirects when accessing other user's position progress" do
        other_position = build(:position, portfolio: other_portfolio, asset: asset)
        other_position.save(validate: false)

        get progress_portfolio_position_path(other_portfolio, other_position)
        expect(response).to redirect_to(portfolios_path)
      end
    end
  end

  describe "GET /portfolios/:portfolio_id/positions/price_for_date" do
    context "when user is not logged in" do
      it "redirects to login page" do
        get price_for_date_portfolio_positions_path(portfolio), params: {
          asset_id: asset.id,
          date: Date.today.to_s
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is logged in" do
      before { sign_in user }

      context "with exact date match" do
        let!(:price_history) { create(:price_history, asset: asset, date: Date.today, close: 250.5) }

        it "returns the price for the exact date" do
          get price_for_date_portfolio_positions_path(portfolio), params: {
            asset_id: asset.id,
            date: Date.today.to_s
          }

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['price'].to_f).to eq(250.5)
          expect(json_response['currency']).to eq(asset.currency)
        end
      end

      context "with no exact match but close date available" do
        let!(:price_history) { create(:price_history, asset: asset, date: 2.days.ago, close: 230.0) }

        it "returns the closest available price" do
          get price_for_date_portfolio_positions_path(portfolio), params: {
            asset_id: asset.id,
            date: Date.today.to_s
          }

          json_response = JSON.parse(response.body)
          expect(json_response['price'].to_f).to eq(230.0)
          expect(json_response['note']).to include('closest available')
        end
      end

      context "with no price data available" do
        it "returns not found error" do
          allow(MarketData::HistoricalPriceFetcher).to receive(:fetch_for_asset).and_return(nil)

          get price_for_date_portfolio_positions_path(portfolio), params: {
            asset_id: asset.id,
            date: Date.today.to_s
          }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('No price data available')
        end
      end

      context "with invalid date format" do
        it "returns bad request error" do
          get price_for_date_portfolio_positions_path(portfolio), params: {
            asset_id: asset.id,
            date: 'invalid-date'
          }

          expect(response).to have_http_status(:bad_request)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('Invalid date format')
        end
      end

      context "with non-existent asset" do
        it "returns not found error" do
          get price_for_date_portfolio_positions_path(portfolio), params: {
            asset_id: 99999,
            date: Date.today.to_s
          }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('Asset not found')
        end
      end

      it "cannot access price data through other user's portfolio" do
        get price_for_date_portfolio_positions_path(other_portfolio), params: {
          asset_id: asset.id,
          date: Date.today.to_s
        }

        expect(response).to redirect_to(portfolios_path)
      end
    end
  end
end
