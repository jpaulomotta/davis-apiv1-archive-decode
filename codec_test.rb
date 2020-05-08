require 'test_helper'

class Davis::CodecTest < ActiveSupport::TestCase
  test "it encodes time and date stamp" do
    # 06/17/2012 in format mm/dd/yyy
    assert_equal 6353, Davis::Codec.encode_date(2012, 6, 17)
    # 15:05
    assert_equal 1505, Davis::Codec.encode_time(15, 5)
  end

  test "it encode a Ruby time into Davis format" do
    t = Time.new(2012, 6, 17, 15, 5)
    assert_equal 416351713, Davis::Codec.encode_timestamp(t)
  end

  test "it decodes a davis timestamp to Ruby format" do
    t = Time.new(2012, 6, 17, 15, 5, 0, '-02:00')
    assert_equal t, Davis::Codec.decode_timestamp(date: 6353, time: 1505, utc_offset: '-02:00')
  end

  test "it decodes temperature" do
    assert_equal 25, Davis::Codec.decode_temperature(766).round
    assert_equal 23, Davis::Codec.decode_temperature(736).round
    assert_equal 100, Davis::Codec.decode_temperature(2120).round
    assert_equal 0, Davis::Codec.decode_temperature(320).round
    assert_nil Davis::Codec.decode_temperature(32767)
    assert_nil Davis::Codec.decode_temperature(-32768)
  end

  test "decode rain" do
    assert_equal 0.2, Davis::Codec.decode_rain(1)
    assert_equal 2, Davis::Codec.decode_rain(10)
    assert_equal 20, Davis::Codec.decode_rain(100)
  end

  test "parse timezone" do 
    assert_equal "-02:00", Davis::Codec.parse_utc_offset("-0200 -02")
    assert_equal "-03:00", Davis::Codec.parse_utc_offset("-0300 -02")
  end

  test "parse solar radiation" do
    assert_equal 1000, Davis::Codec.decode_solar_radiation(1000)
    assert_nil Davis::Codec.decode_solar_radiation(32767)
  end

  test "decode humidity" do
    assert_equal 35, Davis::Codec.decode_humidity(35)
    assert_nil Davis::Codec.decode_humidity(255)

  end

  test "decode wind speed" do
    assert_in_delta 3.2, Davis::Codec.decode_wind_speed(2), 0.1 
    assert_nil Davis::Codec.decode_wind_speed(255)
  end

  test "decode wind direction" do
    assert_equal 'N', Davis::Codec.decode_wind_direction(0)
    assert_equal 'NNE', Davis::Codec.decode_wind_direction(1)
    assert_equal 'NNW', Davis::Codec.decode_wind_direction(15)
    assert_nil Davis::Codec.decode_wind_direction(255)
  end

  test "decode UV index" do
    assert_equal 10, Davis::Codec.decode_uv(100)
    assert_nil Davis::Codec.decode_uv(255)
  end

  test "decode ET" do
    assert_in_delta 25.4, Davis::Codec.decode_et(1000), 0.1
    assert_nil Davis::Codec.decode_et(0)
  end


end