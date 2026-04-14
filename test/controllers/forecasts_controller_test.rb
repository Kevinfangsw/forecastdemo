# frozen_string_literal: true

require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  # --- Index action ---

  test "GET / renders the search form" do
    get root_path
    assert_response :success
    assert_select "h1", /Weather/
    assert_select "input[name='address']"
    assert_select "input[type='submit']"
  end

  test "GET / renders the page title" do
    get root_path
    assert_select "title", /Weather Forecast/
  end

  test "GET / includes autocomplete controller on search form" do
    get root_path
    assert_select "[data-controller='autocomplete']"
    assert_select "[data-autocomplete-target='input']"
    assert_select "[data-autocomplete-target='list']"
  end

  # --- Show action: success ---

  test "GET /forecast renders forecast for a valid address" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_response :success
      assert_match(/72/, response.body)
      assert_match(/Just updated/, response.body)
    end
  end

  test "GET /forecast renders cached indicator when result is from cache" do
    forecast = build_mock_forecast_result(cached: true)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_response :success
      assert_match(/Cached result from/, response.body)
    end
  end

  test "GET /forecast displays labeled current temperature, high, low, and extended forecast" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_response :success

      # Current temperature with label
      assert_match(/Current Temperature/, response.body)
      assert_match(/72/, response.body)
      # Labeled High / Low
      assert_match(/High:/, response.body)
      assert_match(/Low:/, response.body)
      assert_match(/78/, response.body)
      assert_match(/62/, response.body)
      # Extended forecast with column headers (Low before High)
      assert_match(/Today/, response.body)
      assert_match(/5-Day Forecast/, response.body)
      # Weather details section
      assert_match(/Current Details/, response.body)
      assert_match(/Feels Like/, response.body)
      assert_match(/Humidity/, response.body)
      assert_match(/Wind/, response.body)
    end
  end

  test "GET /forecast includes unit toggle buttons" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_select "[data-controller='unit-toggle']"
      assert_select "[data-unit-toggle-target='btnF']"
      assert_select "[data-unit-toggle-target='btnC']"
      assert_select "[data-unit-toggle-target='temp']"
    end
  end

  test "GET /forecast renders data-temp-f attributes for unit toggling" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      # Hero temperature
      assert_select "[data-temp-f='72.0']"
      # Feels like
      assert_select "[data-temp-f='70.0']"
      # Wind with data attribute
      assert_select "[data-wind-mph='8.5']"
    end
  end

  test "GET /forecast includes search form on results page with autocomplete" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_select "input[name='address']"
      assert_select "[data-controller='autocomplete']"
    end
  end

  test "GET /forecast shows condition text in 5-day forecast rows" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      # Condition descriptions should be visible (not just emoji)
      assert_match(/Partly Cloudy/, response.body)
      assert_match(/Mainly Clear/, response.body)
      assert_match(/Clear Sky/, response.body)
    end
  end

  test "GET /forecast shows column headers in 5-day forecast with Low before High" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_match(/Day/, response.body)
      assert_match(/Rain/, response.body)
      assert_match(/Condition/, response.body)
      # Low column appears before High column
      low_pos = response.body.index(">Low<")
      high_pos = response.body.index(">High<")
      assert low_pos < high_pos, "Low column should appear before High column"
    end
  end

  # --- Show action: error handling ---

  test "GET /forecast redirects with alert for blank address" do
    get forecast_path, params: { address: "" }
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Please enter an address/, response.body)
  end

  test "GET /forecast redirects with alert for missing address param" do
    get forecast_path
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Please enter an address/, response.body)
  end

  test "GET /forecast redirects with alert on geocoding error" do
    stub_method(ForecastService, :call, ->(_addr) { raise GeocodingService::GeocodingError, "Could not find location" }) do
      get forecast_path, params: { address: "xyznonexistent" }
      assert_redirected_to root_path
      follow_redirect!
      assert_match(/Could not find location/, response.body)
    end
  end

  test "GET /forecast redirects with alert on weather API error" do
    stub_method(ForecastService, :call, ->(_addr) { raise WeatherService::WeatherApiError, "Service unavailable" }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_redirected_to root_path
      follow_redirect!
      assert_match(/Weather data unavailable/, response.body)
    end
  end

  # --- Show action: network errors ---

  test "GET /forecast handles network timeout gracefully" do
    stub_method(ForecastService, :call, ->(_addr) { raise Net::OpenTimeout, "execution expired" }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_redirected_to root_path
      follow_redirect!
      assert_match(/Unable to reach weather services/, response.body)
    end
  end

  test "GET /forecast handles DNS resolution failure gracefully" do
    stub_method(ForecastService, :call, ->(_addr) { raise SocketError, "getaddrinfo: nodename nor servname provided" }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_redirected_to root_path
      follow_redirect!
      assert_match(/Unable to reach weather services/, response.body)
    end
  end

  test "GET /forecast handles connection refused gracefully" do
    stub_method(ForecastService, :call, ->(_addr) { raise Errno::ECONNREFUSED, "Connection refused" }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_redirected_to root_path
      follow_redirect!
      assert_match(/Unable to reach weather services/, response.body)
    end
  end

  # --- Security ---

  test "GET /forecast safely escapes HTML in address parameter" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "<script>alert('xss')</script>" }
      assert_response :success
      # Rails auto-escapes ERB output — script tag must not appear unescaped
      assert_no_match(/<script>alert/, response.body)
    end
  end

  # --- Edge cases ---

  test "GET /forecast treats whitespace-only address as blank" do
    get forecast_path, params: { address: "   " }
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Please enter an address/, response.body)
  end

  test "GET /forecast preserves address query in results page search field" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_select "input[name='address'][value='Chicago, IL']"
    end
  end

  # --- Show action: coordinate pass-through ---

  test "GET /forecast with lat/lon/postal_code skips geocoding" do
    weather = build_mock_weather
    geocoding_called = false

    stub_method(GeocodingService, :call, ->(_addr) { geocoding_called = true; build_mock_location }) do
      stub_method(WeatherService, :call, ->(**_kw) { weather }) do
        get forecast_path, params: {
          address: "Vancouver, BC, Canada",
          lat: "49.2247",
          lon: "-123.1562",
          postal_code: "V6P"
        }
        assert_response :success
        assert_not geocoding_called, "GeocodingService should not be called when coordinates are provided"
        assert_match(/Vancouver/, response.body)
      end
    end
  end

  test "GET /forecast without lat/lon falls back to geocoding" do
    forecast = build_mock_forecast_result(cached: false)

    stub_method(ForecastService, :call, ->(_addr) { forecast }) do
      get forecast_path, params: { address: "Chicago, IL" }
      assert_response :success
    end
  end

  # --- Autocomplete endpoint ---

  test "GET /autocomplete returns JSON suggestions for valid query" do
    results = stub_geocoder_result(address: "Chicago, Cook County, IL, US")

    stub_method(Geocoder, :search, ->(_q) { results }) do
      get autocomplete_path, params: { q: "Chicago" }, as: :json
      assert_response :success

      json = JSON.parse(response.body)
      assert_instance_of Array, json
      assert json.length > 0
      assert json.first.key?("display_name")
    end
  end

  test "GET /autocomplete returns empty array for short query" do
    get autocomplete_path, params: { q: "Ch" }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "GET /autocomplete returns empty array for blank query" do
    get autocomplete_path, params: { q: "" }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "GET /autocomplete returns empty array on geocoding failure" do
    stub_method(Geocoder, :search, ->(_q) { raise StandardError, "network error" }) do
      get autocomplete_path, params: { q: "Chicago" }, as: :json
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end
  end

  test "GET /autocomplete returns lat, lon, and postal_code in suggestions" do
    results = stub_geocoder_result(
      postal_code: "V6P",
      coordinates: [ 49.2247, -123.1562 ],
      address: "V6P, Vancouver, BC, Canada"
    )

    stub_method(Geocoder, :search, ->(_q) { results }) do
      get autocomplete_path, params: { q: "Vancouver" }, as: :json
      json = JSON.parse(response.body)
      suggestion = json.first

      assert_equal 49.2247, suggestion["lat"]
      assert_equal(-123.1562, suggestion["lon"])
      assert_equal "V6P", suggestion["postal_code"]
    end
  end

  test "GET /autocomplete limits results to 5" do
    # Create 10 mock results
    many_results = 10.times.map do |i|
      OpenStruct.new(
        postal_code: "6060#{i}",
        coordinates: [ 41.87 + i * 0.01, -87.63 ],
        address: "Location #{i}, Chicago, IL",
        data: { "display_name" => "Location #{i}, Chicago, Cook County, Illinois, US" }
      )
    end

    stub_method(Geocoder, :search, ->(_q) { many_results }) do
      get autocomplete_path, params: { q: "Chicago" }, as: :json
      json = JSON.parse(response.body)
      assert_equal 5, json.length
    end
  end
end
