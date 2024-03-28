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

## **Uber Speeds 2018/01 (as downloaded from uber)**

**Number of rows:** `24,074,530`

| Variable          | Type      |  NA |   %NA |  Unique | Description                                              |
|:------------------|:----------|----:|------:|--------:|:---------------------------------------------------------|
| year              | integer   |   0 | 0.00% |       1 | Year                                                     |
| month             | integer   |   0 | 0.00% |       1 | Month                                                    |
| day               | integer   |   0 | 0.00% |      31 | Day                                                      |
| hour              | integer   |   0 | 0.00% |      24 | Hour                                                     |
| utc_timestamp     | POSIXct   |   0 | 0.00% |     744 | Date & time of observations in UTC format                |
| segment_id        | character |   0 | 0.00% | 141,118 | Special Ids assigned to road segments by Uber            |
| start_junction_id | character |   0 | 0.00% | 125,405 | Junction where the segment starts i.e., a roundabout     |
| end_junction_id   | character |   0 | 0.00% | 125,439 | Junction where the segment ends                          |
| osm_way_id        | integer   |   0 | 0.00% |  71,603 | OSM Way Id with One to Many relationship with segment_id |
| osm_start_node_id | integer64 |   0 | 0.00% | 125,405 | Start node Id of OSM corresponding to start_junction_id  |
| osm_end_node_id   | integer64 |   0 | 0.00% | 125,439 | End node Id of OSM corresponding to end_junction_id      |
| speed_mph_mean    | numeric   |   0 | 0.00% |  80,505 | Mean speed of vehicles within an hour                    |
| speed_mph_stddev  | numeric   |   0 | 0.00% |  36,808 | Standard deviation of speed of vehicles in an hour       |

## **Uber Speeds 2018 (selected columns)**

**Number of rows:** `310,003,665`

| Variable       | Type    |  NA |   %NA | Unique | Description                                              |
|:---------------|:--------|----:|------:|-------:|:---------------------------------------------------------|
| utc_timestamp  | POSIXct |   0 | 0.00% |  8,751 | Date & time of observations in UTC format                |
| osm_way_id     | integer |   0 | 0.00% | 85,569 | OSM Way Id with One to Many relationship with segment_id |
| speed_mph_mean | numeric |   0 | 0.00% | 82,535 | Mean speed of vehicles within an hour                    |

## **Uber Speeds 2019 (selected columns)**

**Number of rows:** `321,632,760`

| Variable       | Type    |  NA |   %NA | Unique | Description                                              |
|:---------------|:--------|----:|------:|-------:|:---------------------------------------------------------|
| utc_timestamp  | POSIXct |   0 | 0.00% |  8,657 | Date & time of observations in UTC format                |
| osm_way_id     | integer |   0 | 0.00% | 87,620 | OSM Way Id with One to Many relationship with segment_id |
| speed_mph_mean | numeric |   0 | 0.00% | 78,953 | Mean speed of vehicles within an hour                    |
