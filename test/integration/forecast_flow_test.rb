# frozen_string_literal: true

require "test_helper"

class ForecastFlowTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  test "full flow: homepage -> search -> forecast display with labels" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      # 1. Visit the homepage
      get root_path
      assert_response :success
      assert_select "h1", /Weather/
      assert_select "input[name='address']"

      # 2. Submit an address
      get forecast_path, params: { address: "Chicago, IL" }
      assert_response :success

      # 3. Verify location info
      assert_match(/Chicago/, response.body)
      assert_match(/60601/, response.body)

      # 4. Verify current conditions with labels
      assert_match(/Current Temperature/, response.body)
      assert_match(/72/, response.body)
      assert_match(/Feels Like/, response.body)
      assert_match(/Humidity/, response.body)
      assert_match(/Wind/, response.body)
      assert_match(/Current Details/, response.body)

      # 5. Verify labeled high/low
      assert_match(/High:/, response.body)
      assert_match(/Low:/, response.body)

      # 6. Verify extended forecast with column headers
      assert_match(/5-Day Forecast/, response.body)
      assert_match(/Today/, response.body)
      assert_match(/Condition/, response.body)

      # 7. Verify condition descriptions visible in forecast rows
      assert_match(/Partly Cloudy/, response.body)

      # 8. Verify fresh data indicator
      assert_match(/Just updated/, response.body)

      # 9. Verify unit toggle is present
      assert_select "[data-controller='unit-toggle']"
      assert_select "[data-unit-toggle-target='btnF']"
      assert_select "[data-unit-toggle-target='btnC']"
    end
  end

  test "cached result flow shows amber cache indicator with timestamp" do
    fresh_forecast = build_mock_forecast_result(cached: false)
    cached_forecast = build_mock_forecast_result(cached: true)
    call_count = 0

    service_stub = ->(_addr) {
      call_count += 1
      call_count == 1 ? fresh_forecast : cached_forecast
    }

    stub_method(ForecastService, :call, service_stub) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_match(/Just updated/, response.body)
      assert_no_match(/Cached result from/, response.body)

      get forecast_path, params: { address: "Chicago, IL" }
      assert_match(/Cached result from/, response.body)
      assert_no_match(/Just updated/, response.body)
    end
  end

  test "error flow: invalid address shows flash and returns to search form" do
    stub_method(ForecastService, :call, ->(_addr) { raise GeocodingService::GeocodingError, "Could not find location" }) do
      get forecast_path, params: { address: "invalid" }
      assert_redirected_to root_path

      follow_redirect!
      assert_response :success
      assert_match(/Could not find location/, response.body)
      assert_select "input[name='address']" # Search form still available
    end
  end

  test "weather API error flow shows user-friendly message" do
    stub_method(ForecastService, :call, ->(_addr) { raise WeatherService::WeatherApiError, "Service timeout" }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_redirected_to root_path

      follow_redirect!
      assert_match(/Weather data unavailable/, response.body)
    end
  end

  test "search form is present on the forecast results page for easy re-search" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_select "input[name='address']"
      assert_select "input[type='submit']"
    end
  end

  test "blank address redirects back with helpful error message" do
    get forecast_path, params: { address: "" }
    assert_redirected_to root_path

    follow_redirect!
    assert_match(/Please enter an address/, response.body)
  end

  test "accessibility: pages include proper labels and semantic structure" do
    get root_path
    assert_select "html[lang='en']"
    assert_select "main"
    assert_select "label[for='address']"
  end

  test "temperature data attributes are present for client-side unit conversion" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }

      # Verify data attributes for unit toggle
      assert_select "[data-temp-f]", minimum: 5 # hero + feels_like + 3 daily highs/lows
      assert_select "[data-wind-mph]"
      assert_select "[data-unit-toggle-target='windUnit']"
    end
  end

  test "autocomplete controller is present on both pages" do
    get root_path
    assert_select "[data-controller='autocomplete']"
    assert_select "[data-autocomplete-url-value='/autocomplete']"

    forecast = build_mock_forecast_result(cached: false)
    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_select "[data-controller='autocomplete']"
    end
  end

  test "forecast page has a link back to the home page" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_select "a[href='/']", text: /Home/
    end
  end

  test "5-day forecast uses abbreviated day names to prevent overlap" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      # Day names should be 3-letter abbreviations (Mon, Tue, etc.), not full names
      assert_no_match(/Wednesday/, response.body)
      assert_no_match(/Thursday/, response.body)
      assert_match(/Today/, response.body)
    end
  end
end
