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
  #Example: 416351713 is 06/17/2012 15:05
  def self.encode_date(year, month, day)
    (day + month*32 + (year-2000)*512)
  end

  def self.encode_time(hour, minute)
    (100*hour + minute)
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

  def self.decode_temperature(temp)
    ((temp/10.0) - 32) * (5/9.0)
  end

  # 1 rain click equals 0.2 mm of rain
  def self.decode_rain(rain)
    rain * 0.2
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
    bin_data = archive.unpack('SSSSSSS')
    {
      davis_timestamp: pack_datetime(date: bin_data[0], time: bin_data[1]),
      valid_date_time: decode_timestamp(date: bin_data[0], time: bin_data[1], utc_offset: utc_offset),
      temperature_c: decode_temperature(bin_data[2]),
      rain_amount_mm: decode_rain(bin_data[5]),
      rain_rate_mm_per_hour: decode_rain(bin_data[6]),
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
