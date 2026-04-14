# frozen_string_literal: true

require "test_helper"

class WeatherCodeTest < ActiveSupport::TestCase
  test "returns correct descriptions for known weather codes" do
    assert_equal "Clear Sky",      WeatherCode.description(0)
    assert_equal "Partly Cloudy",  WeatherCode.description(2)
    assert_equal "Heavy Rain",     WeatherCode.description(65)
    assert_equal "Thunderstorm",   WeatherCode.description(95)
  end

  test "returns a non-empty emoji for known weather codes" do
    [ 0, 1, 2, 3, 45, 61, 71, 95 ].each do |code|
      emoji = WeatherCode.emoji(code)
      assert emoji.present?, "Code #{code} should have an emoji"
    end
  end

  test "returns valid Tailwind gradient classes for known weather codes" do
    [ 0, 3, 65, 95 ].each do |code|
      gradient = WeatherCode.gradient(code)
      assert_match(/\Afrom-\S+ via-\S+ to-\S+\z/, gradient, "Code #{code} gradient should be valid")
    end
  end

  test "returns default values for unknown weather codes" do
    info = WeatherCode.for(999)
    assert_equal "Unknown", info[:description]
    assert info[:emoji].present?
    assert info[:gradient].present?
  end

  test "returns default for negative weather codes" do
    assert_equal "Unknown", WeatherCode.description(-1)
  end

  test "all defined codes have description, emoji, and gradient" do
    WeatherCode::CODES.each do |code, info|
      assert info[:description].present?, "Code #{code} missing description"
      assert info[:emoji].present?,       "Code #{code} missing emoji"
      assert info[:gradient].present?,    "Code #{code} missing gradient"
    end
  end

  test "CODES hash is frozen and cannot be mutated" do
    assert WeatherCode::CODES.frozen?
    assert_raises(FrozenError) { WeatherCode::CODES[0] = {} }
  end
end
