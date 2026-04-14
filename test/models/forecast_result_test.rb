# frozen_string_literal: true

require "test_helper"

class ForecastResultTest < ActiveSupport::TestCase
  test "cached? returns false when not cached" do
    result = build_mock_forecast_result(cached: false)
    assert_not result.cached?
  end

  test "cached? returns true when cached" do
    result = build_mock_forecast_result(cached: true)
    assert result.cached?
  end

  test "exposes all expected attributes" do
    result = build_mock_forecast_result

    assert_equal "60601", result.zip_code
    assert_includes result.address, "Chicago"
    assert_instance_of CurrentWeather, result.current
    assert_instance_of Array, result.daily_forecast
    assert result.daily_forecast.all? { |d| d.is_a?(DayForecast) }
    assert_not_nil result.cached_at
  end

  test "defaults daily_forecast to empty array when nil is passed" do
    result = ForecastResult.new(
      address: "Test",
      zip_code: "00000",
      current: nil,
      daily_forecast: nil,
      cached: false,
      cached_at: Time.current
    )
    assert_equal [], result.daily_forecast
  end
end
