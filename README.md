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
This version of the codec is only parsing the temperature, rain fall amount in milimiters and rain rate in milimiters per hour. To parse more parameters you will need to look at the conversion table on page 32 of the manual.



