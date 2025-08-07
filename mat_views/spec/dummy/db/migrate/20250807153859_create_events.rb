# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_type
      t.jsonb :properties
      t.datetime :occurred_at

      t.timestamps
    end
  end
end
