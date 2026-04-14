# frozen_string_literal: true

# Converts a free-form address string into structured location data
# using the Nominatim (OpenStreetMap) geocoding service via the geocoder gem.
#
# Returns a hash with :zip_code, :latitude, :longitude, and :formatted_address.
# Raises GeocodingError if the address cannot be resolved or lacks a postal code.
#
# Canadian postal code handling:
#   Nominatim does not index full 6-character Canadian postal codes (e.g. "V6P 0H7"),
#   but it does index the 3-character Forward Sortation Area (FSA), e.g. "V6P".
#   When a full Canadian postal code returns no results, we extract the FSA and retry.
#
# Reverse-geocode fallback:
#   City-level queries sometimes omit the postal code. When that happens, we
#   reverse-geocode the coordinates to obtain a postal code for the cache key.
class GeocodingService
  class GeocodingError < StandardError; end

  # Matches Canadian postal codes: letter-digit-letter [space] digit-letter-digit.
  # Captures the 3-character FSA prefix in group 1.
  CANADIAN_POSTAL_CODE = /\A([A-Za-z]\d[A-Za-z])\s?\d[A-Za-z]\d\z/

  def self.call(address)
    new(address).call
  end

  def initialize(address)
    @address = address.to_s.strip
  end

  def call
    results = Geocoder.search(@address)

    # Nominatim cannot find full Canadian postal codes (e.g. "V6P 0H7").
    # Extract the 3-character Forward Sortation Area and search for that instead.
    # "V6P" reliably resolves to the correct Canadian neighborhood.
    if results.empty? && (fsa = extract_canadian_fsa(@address))
      results = Geocoder.search(fsa)
    end

    raise GeocodingError, "Could not find location for '#{@address.truncate(100)}'" if results.empty?

    result = results.first
    zip_code = extract_postal_code(result)

    # Postal code is required because it serves as the cache key for forecast data.
    raise GeocodingError, "Could not determine postal code for '#{@address.truncate(100)}'. Try a more specific address." if zip_code.blank?

    {
      zip_code: zip_code,
      latitude: result.coordinates[0],
      longitude: result.coordinates[1],
      formatted_address: result.address
    }
  end

  private

  # Returns the 3-character FSA (e.g. "V6P") if the input is a Canadian postal code,
  # or nil if it isn't. Handles with/without space, any letter case.
  def extract_canadian_fsa(input)
    match = input.match(CANADIAN_POSTAL_CODE)
    match && match[1].upcase
  end

  # Attempts to extract the postal code from a geocoding result.
  # Nominatim omits postal codes for city-level queries. When that happens,
  # reverse-geocode the coordinates to get a postal code for the center point.
  def extract_postal_code(result)
    return result.postal_code if result.postal_code.present?

    lat, lon = result.coordinates
    reverse = Geocoder.search("#{lat},#{lon}").first
    reverse&.postal_code.presence
  end
end
