# frozen_string_literal: true

require "test_helper"

class GeocodingServiceTest < ActiveSupport::TestCase
  test "returns location data for a valid US address" do
    results = stub_geocoder_result
    stub_method(Geocoder, :search, ->(_addr) { results }) do
      location = GeocodingService.call("Chicago, IL")

      assert_equal "60601", location[:zip_code]
      assert_in_delta 41.8781, location[:latitude], 0.001
      assert_in_delta(-87.6298, location[:longitude], 0.001)
      assert_includes location[:formatted_address], "Chicago"
    end
  end

  test "raises GeocodingError when no results are found" do
    stub_method(Geocoder, :search, ->(_addr) { [] }) do
      error = assert_raises(GeocodingService::GeocodingError) do
        GeocodingService.call("xyznonexistent")
      end
      assert_includes error.message, "Could not find location"
    end
  end

  test "falls back to reverse geocode when initial result has no postal code" do
    forward_result = stub_geocoder_result(postal_code: nil)
    reverse_result = stub_geocoder_result(postal_code: "60604")
    call_count = 0

    geocoder_stub = ->(_addr) {
      call_count += 1
      call_count == 1 ? forward_result : reverse_result
    }

    stub_method(Geocoder, :search, geocoder_stub) do
      location = GeocodingService.call("Chicago, IL")
      assert_equal "60604", location[:zip_code]
      assert_equal 2, call_count
    end
  end

  test "raises GeocodingError when both forward and reverse geocode lack postal code" do
    results = stub_geocoder_result(postal_code: nil)
    stub_method(Geocoder, :search, ->(_addr) { results }) do
      error = assert_raises(GeocodingService::GeocodingError) do
        GeocodingService.call("Somewhere without zip")
      end
      assert_includes error.message, "Could not determine postal code"
    end
  end

  test "raises GeocodingError when postal code is blank" do
    results = stub_geocoder_result(postal_code: "")
    stub_method(Geocoder, :search, ->(_addr) { results }) do
      assert_raises(GeocodingService::GeocodingError) do
        GeocodingService.call("Blank zip address")
      end
    end
  end

  test "strips whitespace from address input" do
    results = stub_geocoder_result
    received_address = nil

    stub_method(Geocoder, :search, ->(addr) { received_address = addr; results }) do
      GeocodingService.call("  Chicago, IL  ")
      assert_equal "Chicago, IL", received_address
    end
  end

  test "truncates long addresses in error messages" do
    stub_method(Geocoder, :search, ->(_addr) { [] }) do
      long_address = "A" * 200
      error = assert_raises(GeocodingService::GeocodingError) do
        GeocodingService.call(long_address)
      end
      assert error.message.length < 200
    end
  end

  # --- Canadian postal codes ---

  test "extracts FSA from Canadian postal code and retries search" do
    # First call (full postal code "V6P0H7") returns empty.
    # Second call (FSA "V6P") returns Vancouver results.
    vancouver_result = stub_geocoder_result(
      postal_code: "V6P",
      coordinates: [ 49.2247, -123.1562 ],
      address: "V6P, Marpole, Vancouver, Metro Vancouver Regional District, British Columbia, Canada"
    )
    calls = []

    geocoder_stub = ->(addr) {
      calls << addr
      addr == "V6P" ? vancouver_result : []
    }

    stub_method(Geocoder, :search, geocoder_stub) do
      location = GeocodingService.call("V6P0H7")
      assert_equal "V6P", location[:zip_code]
      assert_in_delta 49.2247, location[:latitude], 0.001
      assert_includes location[:formatted_address], "Vancouver"
      assert_equal [ "V6P0H7", "V6P" ], calls
    end
  end

  test "handles Canadian postal code with space" do
    vancouver_result = stub_geocoder_result(
      postal_code: "V6P",
      coordinates: [ 49.2247, -123.1562 ],
      address: "V6P, Marpole, Vancouver, BC, Canada"
    )
    calls = []

    geocoder_stub = ->(addr) {
      calls << addr
      addr == "V6P" ? vancouver_result : []
    }

    stub_method(Geocoder, :search, geocoder_stub) do
      location = GeocodingService.call("V6P 0H7")
      assert_equal "V6P", location[:zip_code]
      assert_equal [ "V6P 0H7", "V6P" ], calls
    end
  end

  test "handles lowercase Canadian postal code" do
    vancouver_result = stub_geocoder_result(
      postal_code: "V6P",
      coordinates: [ 49.2247, -123.1562 ],
      address: "V6P, Vancouver, BC, Canada"
    )

    geocoder_stub = ->(addr) {
      addr == "V6P" ? vancouver_result : []
    }

    stub_method(Geocoder, :search, geocoder_stub) do
      location = GeocodingService.call("v6p 0h7")
      assert_equal "V6P", location[:zip_code]
    end
  end

  test "does not retry with FSA for non-postal-code input" do
    call_count = 0
    geocoder_stub = ->(_addr) { call_count += 1; [] }

    stub_method(Geocoder, :search, geocoder_stub) do
      assert_raises(GeocodingService::GeocodingError) do
        GeocodingService.call("xyznonexistent")
      end
      assert_equal 1, call_count, "Should not retry for non-postal-code input"
    end
  end

  test "does not retry FSA when initial search succeeds" do
    # Even if input looks like a Canadian postal code, don't retry if first search works
    us_result = stub_geocoder_result(postal_code: "12345")
    call_count = 0

    geocoder_stub = ->(_addr) { call_count += 1; us_result }

    stub_method(Geocoder, :search, geocoder_stub) do
      # "A1A 1A1" matches the pattern but if Nominatim finds something, use it
      location = GeocodingService.call("A1A 1A1")
      assert_equal "12345", location[:zip_code]
      assert_equal 1, call_count
    end
  end
end
