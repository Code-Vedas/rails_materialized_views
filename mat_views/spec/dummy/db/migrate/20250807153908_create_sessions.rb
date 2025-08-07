# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_token
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
