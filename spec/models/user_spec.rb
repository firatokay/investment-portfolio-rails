require 'rails_helper'

RSpec.describe User, type: :model do
  # Note: Portfolio association will be tested in Phase 2
  # describe 'associations' do
  #   it { should have_many(:portfolios).dependent(:destroy) }
  # end

  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe '#full_name' do
    context 'when first_name and last_name are present' do
      let(:user) { build(:user, first_name: 'John', last_name: 'Doe') }

      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    context 'when only first_name is present' do
      let(:user) { build(:user, first_name: 'John', last_name: nil) }

      it 'returns the first name' do
        expect(user.full_name).to eq('John')
      end
    end

    context 'when only last_name is present' do
      let(:user) { build(:user, first_name: nil, last_name: 'Doe') }

      it 'returns the last name' do
        expect(user.full_name).to eq('Doe')
      end
    end

    context 'when both names are blank' do
      let(:user) { build(:user, first_name: nil, last_name: nil) }

      it 'returns the email' do
        expect(user.full_name).to eq(user.email)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'persists to the database' do
      expect { create(:user) }.to change(User, :count).by(1)
    end
  end
end
