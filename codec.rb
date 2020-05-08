# Class to encode and decode Davis stations data
#
# This class uses Ruby unpack and pack parameters.
# To understand more about this parameters read: 
# https://ruby-doc.org/core-2.6.4/String.html#method-i-unpack
#
# Sugested reading:
# Working with bits in Ruby: 
# https://www.webascender.com/blog/working-bits-bytes-ruby/
#
# @author João Paulo Motta Oliveira Silva
#
class Davis::Codec

  DASH_BYTE = 255 #0xFF
  DASH_SHORT = 32767 #0x7FFF
  DASH_SIGNED_SHORT = -32768

  #Example: 416351713 is 06/17/2012 15:05
  def self.encode_date(year, month, day)
    (day + month*32 + (year-2000)*512)
  end

  def self.encode_time(hour, minute)
    (100*hour + minute)
  end


  def self.in_to_mm(v)
    return nil if v.nil? || (v.respond_to?(:strip) && v.strip == '')
    v.to_f * 25.4
  end

  def self.mph_to_kmh(v)
    return nil if v.nil? || (v.respond_to?(:strip) && v.strip == '')
    (v.to_f * 1.60934).round(1)
  end

  # Pack date and time bits in the format expected to query davis archive.
  # The API expects timestamps to be encoded in the format below:
  # They send it in the opposite order for some reason. This is why
  # this function is necessary.
  def self.pack_datetime(date:, time:)
    [time, date].pack('SS').unpack('L').first
  end

  # Format SS (2 x 16 unsigned bits)
  #  TIME, DATE
  # [1505, 6353]
  # Format L (32 unsigned bits)
  # [ 416351713 ]
  def self.encode_timestamp(ruby_time)
    t = encode_time ruby_time.hour, ruby_time.min
    d = encode_date ruby_time.year, ruby_time.month, ruby_time.day
    pack_datetime date: d, time: t
  end

  # These 16 bits hold the date that the archive was written in the following format:
  # Year (7 bits) | Month (4 bits) | Day (5 bits) or: day + month*32 + (year-2000)*512)
  # 
  # Date is packed in this format:
  # 15 14 13 12 11 10 9  8  7  6  5  4  3  2  1  0
  # y  y  y  y  y  y  y  m  m  m  m  d  d  d  d  d 
  #
  # Time is packed in the format:
  # 
  #
  YEAR_MASK = 0xfe00
  MONTH_MASK = 0x1e0
  DAY_MASK = 0x1f
  def self.decode_timestamp(date:, time:, utc_offset:)

    year = ((date & YEAR_MASK) >> 9) + 2000
    month = ((date & MONTH_MASK) >> 5)
    day = date & DAY_MASK

    hour = time/100
    minute = time - (hour*100)
    second = 0
    puts "#{year}-#{month}-#{day} #{hour}:#{minute}" if ENV["DEBUG"]
    Time.new(year, month, day, hour, minute, second, utc_offset)
  end

  # Parses Davis weather station data to ruby hash
  # It expects an String representing an array of 52 bytes chunk of archive data
  # Data is in the format specified by:
  # Vantage ProTM, Vantage Pro2TM and Vantage VueTM Serial Communication Reference Manual v261
  #
  # https://www.davisinstruments.com/support/weather/download/VantageSerialProtocolDocs_v261.pdf
  # Section X.4 Page 32 
  ARCHIVE_SIZE = 52 # bytes 
  def self.decode_data(bytes, utc_offset:)
    archive = nil
    decoded_archive = nil
    data = []
    num_records = bytes.bytesize/ARCHIVE_SIZE
    
    for i in 0..(num_records-1) do
      archive = bytes.byteslice(i * ARCHIVE_SIZE, ARCHIVE_SIZE)
      
      decoded_archive = decode_archive(archive, utc_offset: utc_offset)
      data.push(decoded_archive) if !decoded_archive.nil?
    end
    data
  end


  def self.decode_temperature(temp)
    return nil if temp == DASH_SHORT || temp == DASH_SIGNED_SHORT
    ((temp/10.0) - 32) * (5/9.0)
  end

  # 1 rain click equals 0.2 mm of rain
  def self.decode_rain(rain)
    rain * 0.2
  end

  CARDINALS = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 
    'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW']

  def self.decode_wind_direction(v)
    return nil if v == DASH_BYTE
    CARDINALS[v]
  end

  def self.decode_et(v)
    return nil if v == 0
    in_to_mm(v/1000.0)
  end

  def self.decode_uv(v)
    return nil if v == DASH_BYTE
    v/10.0
  end

  def self.decode_solar_radiation(v)
    return nil if v == DASH_SHORT
    v
  end

  def self.decode_humidity(v)
    return nil if v == DASH_BYTE
    v
  end

  def self.decode_wind_speed(v)
    return nil if v == DASH_BYTE
    mph_to_kmh(v)
  end

  def self.is_dash(archive)
    archive.unpack('SS') == [0xFFFF, 0xFFFF]
  end
  # Decodes 52 bytes Davis weather station archive data.
  # It expects an String representing the archive's 52 bytes
  # Data is in the format specified by:
  # Vantage ProTM, Vantage Pro2TM and Vantage VueTM Serial Communication Reference Manual v261
  #
  # https://www.davisinstruments.com/support/weather/download/VantageSerialProtocolDocs_v261.pdf
  # Section X.4 Page 32 
  #
  def self.decode_archive(archive, utc_offset:)
    if is_dash archive
      puts "DASHVALUE" if ENV["DEBUG"]
      return nil
    end

    bin_data = archive.unpack('SSsssSSSSSSCCCCCCCCSCCSSLCSCCCL')

    #begin 
    valid_date_time = decode_timestamp(date: bin_data[0], time: bin_data[1], utc_offset: utc_offset)
    # rescue ...
    # end 
    
    {
      davis_timestamp: pack_datetime(date: bin_data[0], time: bin_data[1]),
      valid_date_time: valid_date_time,
      high_temperature_c: decode_temperature(bin_data[2]),
      low_temperature_c: decode_temperature(bin_data[3]),
      temperature_c: decode_temperature(bin_data[4]),
      rain_amount_mm: decode_rain(bin_data[5]),
      rain_rate_mm_per_hour: decode_rain(bin_data[6]),
      barometer: bin_data[7] / 1000.0,
      solar_radiation: decode_solar_radiation(bin_data[8]),
      humidity: decode_humidity(bin_data[12]),
      average_wind_speed: decode_wind_speed(bin_data[13]),
      high_wind_speed: decode_wind_speed(bin_data[14]),
      high_wind_direction: decode_wind_direction(bin_data[15]),
      wind_direction: decode_wind_direction(bin_data[16]),
      average_uv: decode_uv(bin_data[17]),
      et: decode_et(bin_data[18]),
      high_solar_radiation: decode_solar_radiation(bin_data[19]),
      high_uv_index: decode_uv(bin_data[20]),
      leaf_temperatures_raw: bin_data[22],
      leaf_wetnesses_raw: bin_data[23],
      soil_temperatures_raw: bin_data[24],
      extra_humidities_raw: bin_data[26],
      extra_temperature_0_raw: bin_data[27],
      extra_temperature_1_raw: bin_data[28],
      extra_temperature_2_raw: bin_data[29],
      soil_moistures_raw: bin_data[30],
    }
  end
  # receives a utc_offset in Davis format
  # eg. -0200 -2
  # and parse it to Ruby format:
  # -02:00
  def self.parse_utc_offset(str)
    groups = str.split(" ")[0].match(/(.\d\d)(\d\d)/)
    return nil if groups.nil?
    "#{groups[1]}:#{groups[2]}"
  end
end
