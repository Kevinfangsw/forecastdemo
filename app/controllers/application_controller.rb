# frozen_string_literal: true

# Base controller for the application.
# Since this is a stateless weather-lookup app (no database, no authentication),
# the base controller only configures importmap-based cache invalidation.
class ApplicationController < ActionController::Base
  # Automatically busts browser caches when JavaScript imports change,
  # by including the importmap digest in the ETag for HTML responses.
  stale_when_importmap_changes
end
