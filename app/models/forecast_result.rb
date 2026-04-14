# frozen_string_literal: true

# Value object wrapping a complete forecast response with cache metadata.
# Built by ForecastService to carry all data the view layer needs in one object.
class ForecastResult
  attr_reader :address, :zip_code, :current, :daily_forecast,
              :cached, :cached_at

  def initialize(address:, zip_code:, current:, daily_forecast:, cached: false, cached_at: nil)
    @address = address
    @zip_code = zip_code
    @current = current
    @daily_forecast = daily_forecast || []
    @cached = cached
    @cached_at = cached_at
  end

  # Whether this result was served from cache rather than a fresh API call.
  def cached?
    @cached
  end
end
