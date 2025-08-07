# frozen_string_literal: true

class User < ApplicationRecord
  has_many :accounts, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
