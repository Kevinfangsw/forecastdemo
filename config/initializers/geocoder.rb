# frozen_string_literal: true

# Configure the geocoder gem to use Nominatim (OpenStreetMap) for address lookup.
# Nominatim is free and requires no API key, but requires a descriptive User-Agent.
# See: https://nominatim.org/release-docs/develop/api/Search/
Geocoder.configure(
  lookup: :nominatim,
  language: :en,
  use_https: true,
  http_headers: {
    "User-Agent" => "ForecastDemo/1.0 (Rails weather forecast demo app)"
  },
  timeout: 10, # seconds — Nominatim can be slow under heavy load
  cache: Rails.cache,
  cache_options: {
    expiration: 1.day, # Geocoding results rarely change; cache aggressively
    prefix: "geocoder:"
  }
)
