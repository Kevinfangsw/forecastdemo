# frozen_string_literal: true

require "test_helper"

class ForecastServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "returns a fresh ForecastResult on first request" do
    location = build_mock_location
    weather = build_mock_weather

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, ->(**_kw) { weather }) do
        result = ForecastService.call("Chicago, IL")

        assert_instance_of ForecastResult, result
        assert_equal "60601", result.zip_code
        assert_not result.cached?
        assert_not_nil result.cached_at
        assert_equal 72.0, result.current.temperature_f
        assert_equal 3, result.daily_forecast.length
      end
    end
  end

  test "returns cached ForecastResult on second request for same zip" do
    location = build_mock_location
    weather = build_mock_weather
    weather_call_count = 0

    weather_stub = ->(**_kw) { weather_call_count += 1; weather }

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, weather_stub) do
        first = ForecastService.call("Chicago, IL")
        assert_not first.cached?

        second = ForecastService.call("Chicago, IL")
        assert second.cached?
        assert_equal 1, weather_call_count, "WeatherService should only be called once"
      end
    end
  end

  test "shares cache across different addresses with the same zip code" do
    location = build_mock_location
    weather = build_mock_weather
    weather_call_count = 0

    weather_stub = ->(**_kw) { weather_call_count += 1; weather }

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, weather_stub) do
        ForecastService.call("123 Main St, Chicago, IL")
        result = ForecastService.call("456 Oak Ave, Chicago, IL")

        assert result.cached?
        assert_equal 1, weather_call_count
      end
    end
  end

  test "cache expires after 30 minutes" do
    location = build_mock_location
    weather = build_mock_weather

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, ->(**_kw) { weather }) do
        first = ForecastService.call("Chicago, IL")
        assert_not first.cached?

        travel ForecastService::CACHE_EXPIRY + 1.minute

        second = ForecastService.call("Chicago, IL")
        assert_not second.cached?, "Should be fresh after cache expiry"
      end
    end
  end

  test "does not expire cache before 30 minutes" do
    location = build_mock_location
    weather = build_mock_weather

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, ->(**_kw) { weather }) do
        ForecastService.call("Chicago, IL")

        travel ForecastService::CACHE_EXPIRY - 1.minute

        result = ForecastService.call("Chicago, IL")
        assert result.cached?, "Should still be cached before expiry"
      end
    end
  end

  test "propagates GeocodingError from GeocodingService" do
    stub_method(GeocodingService, :call, ->(_addr) { raise GeocodingService::GeocodingError, "Not found" }) do
      assert_raises(GeocodingService::GeocodingError) do
        ForecastService.call("invalid")
      end
    end
  end

  test "propagates WeatherApiError from WeatherService" do
    location = build_mock_location

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, ->(**_kw) { raise WeatherService::WeatherApiError, "API down" }) do
        assert_raises(WeatherService::WeatherApiError) do
          ForecastService.call("Chicago, IL")
        end
      end
    end
  end

  test "sets cached_at timestamp on both fresh and cached results" do
    location = build_mock_location
    weather = build_mock_weather

    stub_method(GeocodingService, :call, ->(_addr) { location }) do
      stub_method(WeatherService, :call, ->(**_kw) { weather }) do
        fresh = ForecastService.call("Chicago, IL")
        assert_not_nil fresh.cached_at

        cached = ForecastService.call("Chicago, IL")
        assert_not_nil cached.cached_at
      end
    end
  end

  test "uses different cache entries for different zip codes" do
    chicago_location = build_mock_location(zip_code: "60601")
    nyc_location = build_mock_location(zip_code: "10001", address: "New York, NY 10001, United States")
    weather = build_mock_weather
    weather_call_count = 0

    weather_stub = ->(**_kw) { weather_call_count += 1; weather }

    # Simulate two different addresses resolving to different zips
    call_count = 0
    geocoding_stub = ->(_addr) {
      call_count += 1
      call_count == 1 ? chicago_location : nyc_location
    }

    stub_method(GeocodingService, :call, geocoding_stub) do
      stub_method(WeatherService, :call, weather_stub) do
        ForecastService.call("Chicago, IL")
        ForecastService.call("New York, NY")

        assert_equal 2, weather_call_count, "Different zips should each call WeatherService"
      end
    end
  end

  # --- call_with_coordinates ---

  test "call_with_coordinates skips geocoding and fetches weather directly" do
    weather = build_mock_weather
    geocoding_called = false

    stub_method(GeocodingService, :call, ->(_addr) { geocoding_called = true; build_mock_location }) do
      stub_method(WeatherService, :call, ->(**_kw) { weather }) do
        result = ForecastService.call_with_coordinates(
          address: "Vancouver, BC, Canada",
          latitude: 49.2247,
          longitude: -123.1562,
          postal_code: "V6P"
        )

        assert_not geocoding_called, "GeocodingService should not be called"
        assert_instance_of ForecastResult, result
        assert_equal "V6P", result.zip_code
        assert_equal "Vancouver, BC, Canada", result.address
        assert_not result.cached?
      end
    end
  end

  test "call_with_coordinates uses postal_code as cache key" do
    weather = build_mock_weather
    weather_call_count = 0

    stub_method(WeatherService, :call, ->(**_kw) { weather_call_count += 1; weather }) do
      ForecastService.call_with_coordinates(
        address: "Vancouver, BC", latitude: 49.2247, longitude: -123.1562, postal_code: "V6P"
      )
      result = ForecastService.call_with_coordinates(
        address: "Different St, Vancouver", latitude: 49.2250, longitude: -123.1570, postal_code: "V6P"
      )

      assert result.cached?
      assert_equal 1, weather_call_count, "Second call with same postal_code should be cached"
    end
  end
end
