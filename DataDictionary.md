Data Dictionary
================

## **OSM Roads**

**Number of rows:** `1,077,985`

| Variable | Type           |        NA |    %NA |    Unique | Description                          |
|:---------|:---------------|----------:|-------:|----------:|:-------------------------------------|
| osm_id   | character      |         0 |  0.00% | 1,057,749 | Unique Identifier from OpenStreetMap |
| name     | character      |   745,113 | 69.12% |    98,062 | Name of the entity                   |
| highway  | character      |        96 |  0.01% |        36 | Type of road                         |
| lanes    | character      |   958,937 | 88.96% |        15 | Number of lanes                      |
| maxspeed | character      | 1,004,397 | 93.17% |        32 | Maximum speed                        |
| geom     | sfc_LINESTRING |         0 |  0.00% | 1,057,739 | Geometry information                 |

## **Purple Air 2018-2019**

**Number of rows:** `4,364,868`

| Variable     | Type      |  NA |   %NA |  Unique | Description                                                                                                                                                                                           |
|:-------------|:----------|----:|------:|--------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| time_stamp   | character |   0 | 0.00% |  17,450 | Timestamp of measurement                                                                                                                                                                              |
| pm2.5_atm    | numeric   |   0 | 0.00% | 162,148 | Returns ATM variant average for channel A and B but excluding downgraded channels. Estimated mass concentration PM2.5 (ug/m3). PM2.5 are fine particulates with a diameter of fewer than 2.5 microns. |
| pm2.5_atm_a  | numeric   |   0 | 0.00% | 101,824 | PM2.5 concentration in atmosphere (ug/m^3) - channel A                                                                                                                                                |
| pm2.5_atm_b  | numeric   |   0 | 0.00% |  95,953 | PM2.5 concentration in atmosphere (ug/m^3) - channel B                                                                                                                                                |
| sensor_index | integer   |   0 | 0.00% |     793 | Sensor index                                                                                                                                                                                          |
