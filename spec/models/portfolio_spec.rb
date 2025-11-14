require 'rails_helper'

RSpec.describe Portfolio, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    # Note: Holdings association will be tested in Phase 3
    # it { should have_many(:holdings).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:portfolio) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:user) }
  end

  describe 'factory' do
    it 'creates a valid portfolio' do
      portfolio = build(:portfolio)
      expect(portfolio).to be_valid
    end

    it 'persists to the database' do
      expect { create(:portfolio) }.to change(Portfolio, :count).by(1)
    end

    it 'creates a portfolio with an associated user' do
      portfolio = create(:portfolio)
      expect(portfolio.user).to be_present
      expect(portfolio.user).to be_a(User)
    end
  end

  describe 'attributes' do
    let(:portfolio) { create(:portfolio) }

    it 'has a name' do
      expect(portfolio.name).to be_present
    end

    it 'has a description' do
      expect(portfolio.description).to be_present
    end

    it 'belongs to a user' do
      expect(portfolio.user_id).to be_present
    end
  end
end
