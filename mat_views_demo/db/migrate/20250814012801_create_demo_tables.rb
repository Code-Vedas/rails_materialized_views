# frozen_string_literal: true

class CreateDemoTables < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.timestamps
    end
    add_index :users, :email

    create_table :accounts do |t|
      t.references :user, null: false,
                          foreign_key: true
      t.string :plan
      t.string :status
      t.timestamps
    end

    create_table :events do |t|
      t.references :user, null: false,
                          foreign_key: true
      t.string :event_type
      t.jsonb :properties
      t.datetime :occurred_at
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false,
                          foreign_key: true
      t.string :session_token
      t.datetime :started_at
      t.datetime :ended_at
      t.timestamps
    end
  end
end
