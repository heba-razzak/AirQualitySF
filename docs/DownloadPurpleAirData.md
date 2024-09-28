Download PurpleAir Data
================

## Load required libraries

``` r
library(dplyr)        # Data manipulation
library(sf)           # Spatial data manipulation
library(ggplot2)      # Data visualization
library(lubridate)    # Working with dates
library(tigris)       # Counties map data
library(kableExtra)   # Printing formatted tables
library(purpleAirAPI) # Download PurpleAir Data
library(DataOverviewR)
```

## Download PurpleAir Sensor Data

### Fields: sensor_index, date_created, last_seen, latitude, longitude

PurpleAir Documentation:  
[Sensor
fields](https://api.purpleair.com/#api-sensors-get-sensor-data)  
[Field
Descriptions](https://community.purpleair.com/t/api-history-fields-descriptions/4652)

``` r
# Download sensor data
pa <- getPurpleairSensors(apiReadKey = api_key) %>% na.omit()
```

### PurpleAir Sensor Data

| sensor_index | date_created | last_seen  | latitude | longitude |
|-------------:|:-------------|:-----------|---------:|----------:|
|           53 | 2016-02-04   | 2024-09-24 | 40.24674 | -111.7048 |
|           77 | 2016-03-02   | 2024-09-24 | 40.75082 | -111.8253 |
|          182 | 2016-08-01   | 2024-09-24 | 49.16008 | -123.7423 |

## Convert PurpleAir data frame to shapefile

``` r
# Convert the PurpleAir data frame to an sf object
pa_sf <- st_as_sf(pa, coords=c("longitude", "latitude"), crs = crs)
```

### PurpleAir Sensor Shapefile

| sensor_index | date_created | last_seen  | geometry                   |
|-------------:|:-------------|:-----------|:---------------------------|
|           53 | 2016-02-04   | 2024-09-24 | POINT (-111.7048 40.24674) |
|           77 | 2016-03-02   | 2024-09-24 | POINT (-111.8253 40.75082) |
|          182 | 2016-08-01   | 2024-09-24 | POINT (-123.7423 49.16008) |

## **PurpleAir Sensors Shapefile**

`26,925` rows

`0` rows with missing values

|    Column    |   Type    |                                   Description                                   | NA_Count | N_Unique |
|:------------:|:---------:|:-------------------------------------------------------------------------------:|:--------:|:--------:|
| sensor_index |  numeric  | The sensor’s index. Can be used to add a sensor to a group or view its details. |    0     |  26,925  |
| date_created |   Date    |              The UNIX time stamp from when the device was created.              |    0     |  1,659   |
|  last_seen   |   Date    | The UNIX time stamp of the last time the server received data from the device.  |    0     |    31    |
|   geometry   | sfc_POINT |                                    Geometry                                     |    0     |  26,776  |

## Map PurpleAir sensors in Bay Area

Filter sensors within a bounding box of the bay area

``` r
# Define bounding box for the Bay Area
bbox <- c(xmin = -123.8, ymin = 36.9, xmax = -121.0, ymax = 39.0)
bbox_sf <- st_as_sfc(st_bbox(bbox))
st_crs(bbox_sf) <- crs

# Filter sensors within bounding box
purpleairs_sf <- st_intersection(pa_sf, bbox_sf)
total_sensors <- length(unique(purpleairs_sf$sensor_index))

# Load California county boundaries for mapping
ca <- counties("California", cb = TRUE)

# Plot the sensors
ggplot() + 
  geom_sf(data = ca, color = "black", fill = "antiquewhite", size = 0.25) +
  geom_sf(data = purpleairs_sf, color = "purple", size = 0.1) +
  coord_sf(xlim = c(-123.8, -121.0), ylim = c(36.9, 39.0)) +
  theme(panel.background = element_rect(fill = "aliceblue")) + 
  labs(title = "PurpleAir Sensors in the Bay Area", 
       subtitle = paste0(total_sensors," sensors"),
       x = "Longitude", y = "Latitude")
```

![](DownloadPurpleAirData_files/figure-gfm/sensors-bayarea-1.png)<!-- -->

## Set inputs for PurpleAir data

``` r
fields <- c("pm2.5_atm", "pm2.5_atm_a", "pm2.5_atm_b", "rssi", "uptime",
            "memory", "humidity", "temperature", "pressure", "analog_input")
average <- "60"

# Date range for data download (2018-2019)
start_date <- as.Date("2018-01-01")
end_date <- as.Date("2019-12-31")
```

## Download Purple Air Hourly Data for 2018-2019

``` r
# only download if file doesnt exist
filename <- paste0("purpleair_", start_date, "_", end_date, ".csv")
filepath <- file.path(purpleair_directory, filename)
if (!file.exists(filepath)) {
  start_time <- Sys.time()
  
  filtered_sensors_sf <- purpleairs_sf %>% 
    filter(last_seen >= start_date) %>% 
    filter(date_created <= end_date)
  
  sensor_ids <- unique(filtered_sensors_sf$sensor_index)
  
  # Get PurpleAir data
  purpleair_data <- getSensorHistory(
    sensorIndex = sensor_ids,
    apiReadKey = api_key,
    startDate = start_date,
    endDate = end_date,
    average = average,
    fields = fields
  )
  # Save to CSV file
  write.csv(
    purpleair_data,
    file = filepath,
    row.names = FALSE)
}
```

# PurpleAir Bay Area Hourly 2018-2019

| time_stamp          | rssi | uptime | memory | humidity | temperature | pressure | analog_input | pm2.5_atm | pm2.5_atm_a | pm2.5_atm_b | sensor_index |
|:--------------------|-----:|-------:|-------:|---------:|------------:|---------:|-------------:|----------:|------------:|------------:|-------------:|
| 2018-01-01 00:00:00 |  -56 |  59100 |  28159 |   35.676 |      71.729 |       NA |        0.010 |   47.9165 |      48.090 |      47.743 |          767 |
| 2018-01-01 01:00:00 |  -57 |  62700 |  28159 |   38.911 |      68.619 |       NA |        0.016 |   45.9330 |      46.117 |      45.749 |          767 |
| 2018-01-01 02:00:00 |  -57 |  66300 |  28164 |   41.358 |      66.688 |       NA |        0.019 |   43.3735 |      43.434 |      43.313 |          767 |

## **PurpleAir Bay Area Hourly 2018-2019**

`5,114,035` rows

`1,209,411` rows with missing values

|    Column    |   Type    |                                                                               Description                                                                               | NA_Count | NA_Percentage | N_Unique |                             Top_3                             |
|:------------:|:---------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:--------:|:-------------:|:--------:|:-------------------------------------------------------------:|
|  time_stamp  | character |                                                               UTC (Unix) time stamp for that row of data.                                                               |    0     |               |  17,519  | 2019-12-31 21:00:00, 2019-12-31 22:00:00, 2019-12-29 22:00:00 |
|     rssi     |  integer  |                                                                        The WiFi signal strength.                                                                        |  3,776   |      0%       |   130    |                         -60, -61, -59                         |
|    uptime    |  numeric  |                                             The time in minutes since the firmware started as last reported by the sensor.                                              |  3,776   |      0%       | 389,292  |                       1860, 4140, 1980                        |
|    memory    |  integer  |                                                                         Free HEAP memory in Kb.                                                                         |  1,029   |      0%       |  22,867  |                      30920, 30752, 31144                      |
|   humidity   |  numeric  | Relative humidity inside of the sensor housing (%). This matches the ‘Raw Humidity’ map layer and on average is 4% lower than ambient conditions. Null if not equipped. |  82,721  |      2%       |  73,584  |                          32, 31, 33                           |
| temperature  |  numeric  | Temperature inside of the sensor housing (F). This matches the ‘Raw Temperature’ map layer and on average is 8°F higher than ambient conditions. Null if not equipped.  |  82,721  |      2%       |  65,853  |                          81, 82, 80                           |
|   pressure   |  numeric  |                                                                     Current pressure in Millibars.                                                                      | 378,567  |      7%       | 130,044  |                    667.92, 683.98, 1149.35                    |
| analog_input |  numeric  |                                 If anything is connected to it, the analog voltage on ADC input of the PurpleAir sensor control board.                                  |  1,246   |      0%       |    95    |                         0.02, 0.03, 0                         |
|  pm2.5_atm   |  numeric  |                           Estimated mass concentration PM2.5 (µg/m³). PM2.5 are fine particulates with a diameter of fewer than 2.5 microns.                            |   155    |      0%       | 163,641  |                        0, 0.002, 0.03                         |
| pm2.5_atm_a  |  numeric  |                                                                         Channel A ATM variant.                                                                          |  3,786   |      0%       | 100,587  |                        0, 0.004, 0.09                         |
| pm2.5_atm_b  |  numeric  |                                                                         Channel B ATM variant.                                                                          | 852,724  |      17%      |  97,589  |                         0, 0.07, 0.09                         |
| sensor_index |  integer  |                                             The sensor’s index. Can be used to add a sensor to a group or view its details.                                             |    0     |               |   934    |                       2883, 3894, 3082                        |

## **PurpleAir Bay Area Hourly 2018-2019**

`5,114,035` rows

`1,209,411` rows with missing values

|   variable   |                 mean                 |                    sd                     |    p25    |   median   |     p75      |
|:------------:|:------------------------------------:|:-----------------------------------------:|:---------:|:----------:|:------------:|
|     rssi     |                -62.83                |                   17.13                   |  -74.00   |   -65.00   |    -56.00    |
|    uptime    |              679,822.46              |                955,614.65                 | 25,220.00 | 175,980.00 | 1,017,120.00 |
|    memory    |              24,473.53               |                 5,720.47                  | 19,469.00 | 20,783.00  |  30,490.00   |
|   humidity   |                44.36                 |                   15.75                   |   32.00   |   43.00    |    57.39     |
| temperature  |              822,717.49              |               41,133,906.77               |   61.40   |   70.95    |    80.60     |
|   pressure   |               1,002.94               |                  628.03                   |  999.41   |  1,008.50  |   1,013.90   |
| analog_input |                 0.02                 |                   0.02                    |   0.01    |    0.02    |     0.04     |
|  pm2.5_atm   | 4,756,845,832,810,399,147,229,184.00 | 6,722,816,125,097,543,123,125,403,648.00  |   1.28    |    3.67    |     8.09     |
| pm2.5_atm_a  | 9,520,451,456,570,696,920,989,696.00 | 13,450,408,184,278,803,954,117,115,904.00 |   1.23    |    3.63    |     8.03     |
| pm2.5_atm_b  |                14.76                 |                  153.75                   |   1.43    |    4.06    |     8.71     |
| sensor_index |              17,778.09               |                 8,520.68                  | 14,063.00 | 19,299.00  |  21,707.00   |

numeric

|  variable  |    min     |    max     |   median   | n_unique |
|:----------:|:----------:|:----------:|:----------:|:--------:|
| time_stamp | 2018-01-01 | 2019-12-31 | 2019-06-22 |   730    |

date

## Map PurpleAir Sensors Bay Area (2018-2019)

``` r
purpleairs_sf_filtered <- purpleairs_sf %>% 
  filter(sensor_index %in% unique(purpleair_data$sensor_index)) %>% 
  select(sensor_index)

ca <- counties("California", cb = TRUE)
num_sensors <- length(unique(purpleairs_sf_filtered$sensor_index))

ggplot() + 
  geom_sf(data = ca, color="black", fill="antiquewhite", size=0.25) +
  geom_sf(data = purpleairs_sf_filtered, color = "purple", size = 0.1) +
  coord_sf(xlim = c(-123.8, -121.0), ylim = c(36.9, 39.0)) +
  theme(panel.background = element_rect(fill = "aliceblue")) + 
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("PurpleAir Sensors in the Bay Area", subtitle = paste0(num_sensors," sensors in 2018-2019"))
```

![](DownloadPurpleAirData_files/figure-gfm/map-sensors-1.png)<!-- -->

## Plot Sensors by Month

``` r
# Add column for month
purpleair_data$month <- format(as.Date(purpleair_data$time_stamp), "%Y-%m")

# Sensors for each month
monthly_sensors <- purpleair_data %>% select(month, sensor_index) %>% distinct()

sensor_counts <- monthly_sensors %>%
  group_by(month) %>%
  summarise(sensor_count = n_distinct(sensor_index))

ggplot(sensor_counts, aes(x = month, y = sensor_count)) +
  geom_bar(stat = "identity", fill = "lavender", color = "black") +
  labs(title = "Active PurpleAir Sensors By Month",
       x = "Month",
       y = "Number of Sensors") +
  scale_y_continuous(breaks = seq(0, max(sensor_counts$sensor_count) + 100, by = 100)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

![](DownloadPurpleAirData_files/figure-gfm/monthly-sensors-1.png)<!-- -->
