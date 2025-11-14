class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :portfolios, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true

  # Optional: Method to get full name
  def full_name
    "#{first_name} #{last_name}".strip.presence || email
  end
end
