# frozen_string_literal: true

enable_integrity!
pin 'mat_views/application'
pin '@hotwired/turbo-rails',                  to: 'turbo.min.js'
pin '@hotwired/stimulus',                     to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading',             to: 'stimulus-loading.js'

pin_all_from MatViews::Engine.root.join('app/javascript/mat_views/controllers'), under: 'mat_views/controllers'
