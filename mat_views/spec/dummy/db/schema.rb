# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 20_250_807_032_860) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_catalog.plpgsql'

  create_table 'mat_view_definitions', force: :cascade do |t|
    t.string 'name', null: false
    t.text 'sql', null: false
    t.string 'refresh_strategy', default: 'manual'
    t.string 'schedule_cron'
    t.jsonb 'unique_index_columns', default: []
    t.jsonb 'dependencies', default: []
    t.datetime 'last_refreshed_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'mat_view_refresh_runs', force: :cascade do |t|
    t.bigint 'mat_view_definition_id', null: false
    t.integer 'status', default: 0, null: false
    t.datetime 'started_at'
    t.datetime 'finished_at'
    t.integer 'duration_ms'
    t.integer 'rows_count'
    t.text 'error'
    t.jsonb 'meta', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['mat_view_definition_id'], name: 'index_mat_view_refresh_runs_on_mat_view_definition_id'
  end

  add_foreign_key 'mat_view_refresh_runs', 'mat_view_definitions'
end
