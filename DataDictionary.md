Data Dictionary
================

## **OSM Roads**

**Number of rows:** `1,084,693`

| Variable | Type           |        NA |    %NA |    Unique | Description                          |
|:---------|:---------------|----------:|-------:|----------:|:-------------------------------------|
| osm_id   | character      |         0 |  0.00% | 1,064,435 | Unique Identifier from OpenStreetMap |
| name     | character      |   750,944 | 69.23% |    98,214 | Name of the entity                   |
| highway  | character      |       102 |  0.01% |        35 | Type of road                         |
| lanes    | character      |   965,073 | 88.97% |        15 | Number of lanes                      |
| maxspeed | character      | 1,010,529 | 93.16% |        33 | Maximum speed                        |
| geom     | sfc_LINESTRING |         0 |  0.00% | 1,064,430 | Geometry information                 |

## **PurpleAir Sensors**

**Number of rows:** `25,416`

| Variable     | Type      |  NA |   %NA | Unique | Description          |
|:-------------|:----------|----:|------:|-------:|:---------------------|
| sensor_index | numeric   |   0 | 0.00% | 25,416 | Sensor index         |
| geom         | sfc_POINT |   0 | 0.00% | 25,297 | Geometry information |

## **Purple Air 2018-2019**

**Number of rows:** `4,364,868`

| Variable     | Type    |  NA |   %NA |  Unique | Description                                                                                                                                                                                           |
|:-------------|:--------|----:|------:|--------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| time_stamp   | POSIXct |   0 | 0.00% |  17,450 | Timestamp of measurement                                                                                                                                                                              |
| pm2.5_atm    | numeric |   0 | 0.00% | 162,148 | Returns ATM variant average for channel A and B but excluding downgraded channels. Estimated mass concentration PM2.5 (ug/m3). PM2.5 are fine particulates with a diameter of fewer than 2.5 microns. |
| pm2.5_atm_a  | numeric |   0 | 0.00% | 101,824 | PM2.5 concentration in atmosphere (ug/m^3) - channel A                                                                                                                                                |
| pm2.5_atm_b  | numeric |   0 | 0.00% |  95,953 | PM2.5 concentration in atmosphere (ug/m^3) - channel B                                                                                                                                                |
| sensor_index | integer |   0 | 0.00% |     793 | Sensor index                                                                                                                                                                                          |

## **Uber Speeds 2018**

**Number of rows:** `310,003,665`

| Variable       | Type    |  NA |   %NA | Unique | Description                                              |
|:---------------|:--------|----:|------:|-------:|:---------------------------------------------------------|
| utc_timestamp  | POSIXct |   0 | 0.00% |  8,751 | Date & time of observations in UTC format                |
| osm_way_id     | integer |   0 | 0.00% | 85,569 | OSM Way Id with One to Many relationship with segment_id |
| speed_mph_mean | numeric |   0 | 0.00% | 82,535 | Mean speed of vehicles within an hour                    |

## **Uber Speeds 2019**

**Number of rows:** `321,632,760`

| Variable       | Type    |  NA |   %NA | Unique | Description                                              |
|:---------------|:--------|----:|------:|-------:|:---------------------------------------------------------|
| utc_timestamp  | POSIXct |   0 | 0.00% |  8,657 | Date & time of observations in UTC format                |
| osm_way_id     | integer |   0 | 0.00% | 87,620 | OSM Way Id with One to Many relationship with segment_id |
| speed_mph_mean | numeric |   0 | 0.00% | 78,953 | Mean speed of vehicles within an hour                    |

## **Weather Stations**

**Number of rows:** `588,075`

| Variable        | Type      |      NA |    %NA | Unique | Description                                         |
|:----------------|:----------|--------:|-------:|-------:|:----------------------------------------------------|
| station         | character |       0 |  0.00% |     37 | Weather station identifier                          |
| timestamp       | POSIXct   |       0 |  0.00% | 17,496 | Timestamp of the observation (UTC)                  |
| temp_fahrenheit | numeric   |   9,514 |  1.62% |  3,470 | Air Temperature in Fahrenheit, typically @ 2 meters |
| rel_humidity    | numeric   |  11,860 |  2.02% | 34,010 | Relative Humidity in %                              |
| wind_direction  | numeric   |   5,113 |  0.87% |  3,322 | Wind Direction in degrees from north                |
| wind_speed      | numeric   |   1,216 |  0.21% |  2,201 | Wind Speed in knots                                 |
| wind_gust       | numeric   | 512,330 | 87.12% |    579 | Wind Gust in knots                                  |
| lon             | numeric   |       0 |  0.00% |     37 | Longitude                                           |
| lat             | numeric   |       0 |  0.00% |     37 | Latitude                                            |
