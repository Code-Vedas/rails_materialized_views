# frozen_string_literal: true

Rails.application.routes.draw do
  mount MatViews::Engine => '/mat_views'
end
