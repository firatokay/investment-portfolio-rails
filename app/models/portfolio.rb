class Portfolio < ApplicationRecord
  belongs_to :user
  has_many :holdings, dependent: :destroy

  validates :name, presence: true
  validates :user, presence: true
end
