# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

class User < ApplicationRecord
  has_many :accounts, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
