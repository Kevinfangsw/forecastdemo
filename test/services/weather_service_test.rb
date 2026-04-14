# frozen_string_literal: true

require "test_helper"

class WeatherServiceTest < ActiveSupport::TestCase
  test "parses a successful API response into structured weather data" do
    response = mock_http_response(200, build_mock_open_meteo_response)

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      result = WeatherService.call(latitude: 41.8781, longitude: -87.6298)

      # Current weather
      assert_instance_of CurrentWeather, result[:current]
      assert_equal 72.0, result[:current].temperature_f
      assert_equal "Partly Cloudy", result[:current].condition
      assert_equal "⛅", result[:current].icon
      assert_equal 45, result[:current].humidity
      assert_equal 8.5, result[:current].wind_mph
      assert_equal 70.0, result[:current].feels_like_f
      assert_equal 2, result[:current].weather_code

      # Daily forecast
      assert_equal 3, result[:daily_forecast].length
      first_day = result[:daily_forecast].first
      assert_instance_of DayForecast, first_day
      assert_equal Date.today, first_day.date
      assert_equal 78.0, first_day.high_f
      assert_equal 62.0, first_day.low_f
      assert_equal "Partly Cloudy", first_day.condition
      assert_equal 10, first_day.chance_of_rain
    end
  end

  test "raises WeatherApiError on non-success HTTP response" do
    response = mock_http_response(400, { "reason" => "Bad request" })

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      error = assert_raises(WeatherService::WeatherApiError) do
        WeatherService.call(latitude: 0, longitude: 0)
      end
      assert_includes error.message, "Bad request"
    end
  end

  test "provides fallback error message when API reason is missing" do
    response = mock_http_response(500, {})

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      error = assert_raises(WeatherService::WeatherApiError) do
        WeatherService.call(latitude: 0, longitude: 0)
      end
      assert_includes error.message, "HTTP 500"
    end
  end

  test "returns empty daily forecast when daily data is nil" do
    data = build_mock_open_meteo_response
    data["daily"] = nil
    response = mock_http_response(200, data)

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      result = WeatherService.call(latitude: 41.8781, longitude: -87.6298)
      assert_equal [], result[:daily_forecast]
    end
  end

  test "raises WeatherApiError when current data is nil" do
    data = build_mock_open_meteo_response
    data["current"] = nil
    response = mock_http_response(200, data)

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      error = assert_raises(WeatherService::WeatherApiError) do
        WeatherService.call(latitude: 41.8781, longitude: -87.6298)
      end
      assert_includes error.message, "no current conditions"
    end
  end

  test "maps WMO weather codes correctly" do
    data = build_mock_open_meteo_response
    data["current"]["weather_code"] = 95
    response = mock_http_response(200, data)

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      result = WeatherService.call(latitude: 41.8781, longitude: -87.6298)
      assert_equal "Thunderstorm", result[:current].condition
      assert_equal "⛈️", result[:current].icon
      assert_equal 95, result[:current].weather_code
    end
  end

  test "handles unknown WMO weather codes gracefully" do
    data = build_mock_open_meteo_response
    data["current"]["weather_code"] = 999
    response = mock_http_response(200, data)

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      result = WeatherService.call(latitude: 41.8781, longitude: -87.6298)
      assert_equal "Unknown", result[:current].condition
    end
  end

  test "defaults chance_of_rain to zero when missing from response" do
    data = build_mock_open_meteo_response
    data["daily"]["precipitation_probability_max"] = [ nil, nil, nil ]
    response = mock_http_response(200, data)

    stub_method(HTTParty, :get, ->(*_args, **_kwargs) { response }) do
      result = WeatherService.call(latitude: 41.8781, longitude: -87.6298)
      result[:daily_forecast].each do |day|
        assert_equal 0, day.chance_of_rain
      end
    end
  end
end
