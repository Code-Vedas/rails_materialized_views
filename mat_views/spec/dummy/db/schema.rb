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

ActiveRecord::Schema[7.2].define(version: 20_250_807_153_908) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_catalog.plpgsql'

  create_table 'accounts', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.string 'plan'
    t.string 'status'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_accounts_on_user_id'
  end

  create_table 'events', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.string 'event_type'
    t.jsonb 'properties'
    t.datetime 'occurred_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_events_on_user_id'
  end

  create_table 'mat_view_create_runs', force: :cascade do |t|
    t.bigint 'mat_view_definition_id', null: false, comment: 'Reference to the materialized view definition being created'
    t.integer 'status', default: 0, null: false, comment: '0=pending,1=running,2=success,3=failed'
    t.datetime 'started_at', comment: 'Timestamp when the creation operation started'
    t.datetime 'finished_at', comment: 'Timestamp when the creation operation finished'
    t.integer 'duration_ms', comment: 'Duration of the creation operation in milliseconds'
    t.text 'error', comment: 'Error message if the creation operation failed'
    t.jsonb 'meta', default: {}, null: false, comment: 'Additional metadata about the creation run, such as job ID or parameters'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['mat_view_definition_id'], name: 'index_mat_view_create_runs_on_mat_view_definition_id'
  end

  create_table 'mat_view_definitions', force: :cascade do |t|
    t.string 'name', null: false, comment: 'The name of the materialized view'
    t.text 'sql', null: false, comment: 'The SQL query defining the materialized view'
    t.integer 'refresh_strategy', default: 0, null: false,
                                  comment: 'Strategy for refreshing the materialized view. Options: regular, concurrent, swap'
    t.string 'schedule_cron', comment: 'Cron schedule for automatic refresh of the materialized view'
    t.jsonb 'unique_index_columns', default: [], comment: 'Columns used for unique indexing, if any'
    t.jsonb 'dependencies', default: [], comment: 'Dependencies of the materialized view, such as other views or tables'
    t.datetime 'last_refreshed_at', comment: 'Timestamp of the last refresh operation'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'mat_view_delete_runs', force: :cascade do |t|
    t.bigint 'mat_view_definition_id', null: false, comment: 'Reference to the materialized view definition being deleted from'
    t.integer 'status', default: 0, null: false, comment: '0=pending,1=running,2=success,3=failed'
    t.datetime 'started_at', comment: 'Timestamp when the delete operation started'
    t.datetime 'finished_at', comment: 'Timestamp when the delete operation finished'
    t.integer 'duration_ms', comment: 'Duration of the delete operation in milliseconds'
    t.text 'error', comment: 'Error message if the delete operation failed'
    t.jsonb 'meta', default: {}, comment: 'Additional metadata about the delete run, such as job ID or parameters'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['mat_view_definition_id'], name: 'index_mat_view_delete_runs_on_mat_view_definition_id'
  end

  create_table 'mat_view_refresh_runs', force: :cascade do |t|
    t.bigint 'mat_view_definition_id', null: false, comment: 'Reference to the materialized view definition being refreshed'
    t.integer 'status', default: 0, null: false, comment: '0=pending,1=running,2=success,3=failed'
    t.datetime 'started_at', comment: 'Timestamp when the refresh operation started'
    t.datetime 'finished_at', comment: 'Timestamp when the refresh operation finished'
    t.integer 'duration_ms', comment: 'Duration of the refresh operation in milliseconds'
    t.integer 'rows_count', comment: 'Number of rows in the materialized view after refresh'
    t.text 'error', comment: 'Error message if the refresh operation failed'
    t.jsonb 'meta', default: {}, comment: 'Additional metadata about the refresh run, such as job ID or parameters'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['mat_view_definition_id'], name: 'index_mat_view_refresh_runs_on_mat_view_definition_id'
  end

  create_table 'sessions', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.string 'session_token'
    t.datetime 'started_at'
    t.datetime 'ended_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_sessions_on_user_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'name'
    t.string 'email'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['email'], name: 'index_users_on_email'
  end

  add_foreign_key 'accounts', 'users'
  add_foreign_key 'events', 'users'
  add_foreign_key 'mat_view_create_runs', 'mat_view_definitions'
  add_foreign_key 'mat_view_delete_runs', 'mat_view_definitions'
  add_foreign_key 'mat_view_refresh_runs', 'mat_view_definitions'
  add_foreign_key 'sessions', 'users'
end
