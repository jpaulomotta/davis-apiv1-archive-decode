# Davis Archive Decoder
Parses Davis weather station data to ruby hash

Data is in the format specified by:

Vantage ProTM, Vantage Pro2TM and Vantage VueTM Serial Communication Reference Manual v261

https://www.davisinstruments.com/support/weather/download/VantageSerialProtocolDocs_v261.pdf

Section X.4 Page 32 

## Usage
Call the function decode_data with the archive and the station UTC offset 

Example for UTC Offset -3 (America/Sao_Paulo)

```
Davis::Codec.decode_data(bytes, "-0300 -03")
```

## Parsed parameters

- davis_timestamp
- high_temperature_c
- low_temperature_c
- temperature_c
- rain_amount_mm
- rain_rate_mm_per_hour
- barometer
- solar_radiation
- humidity
- average_wind_speed
- high_wind_speed
- high_wind_direction
- wind_direction
- average_uv
- et
- high_solar_radiation
- high_uv_index
- leaf_temperatures_raw
- leaf_wetnesses_raw
- soil_temperatures_raw
- extra_humidities_raw
- extra_temperature_0_raw
- extra_temperature_1_raw
- extra_temperature_2_raw
- soil_moistures_raw

