# Preprocessing PurpleAir

## Load required libraries

```r
library(dplyr)      # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(ggplot2)    # Plots
library(plotly)     # Interactive plots
library(lubridate)  # Dates
library(sf)         # Shapefiles
library(leaflet)    # Interactive maps
library(kableExtra) # Printing formatted tables
library(zoo)        # for rolling calculations
library(PurpleAirAPI)
```

## Read files

```r
# Read files
# Read filtered dataset
purpleair_filtered <- fread(paste0(preprocessing_directory, "/purpleair_filtered_2018-2019.csv"))

epa_data <- read.csv(paste0(preprocessing_directory, "/EPA_airquality.csv"))
# Download sensor location data
pa_sensors <- getPurpleairSensors(apiReadKey = api_key) %>%
  filter(sensor_index %in% unique(purpleair_filtered$sensor_index))
# Convert the PurpleAir data frame to an sf object
pa_sensors <- pa_sensors %>% na.omit()
pa_sensors <- st_as_sf(pa_sensors, coords=c("longitude", "latitude"), crs = 4326)
```

## Dataset info

    ## Number of Sensors:  621
    ##
    ##  Number of Rows:  4146805
    ##
    ##  Date Range:  2018-01-01  to  2019-12-31

```r
# Plot the distribution of PM2.5 levels
ggplot(purpleair_filtered, aes(x = pm2.5_atm)) +
  geom_histogram(binwidth = 1, fill = "steelblue", color = "black") +
  labs(
    title = "Distribution of PM2.5 Levels",
    subtitle = "x-axis limit set to 100; more data points beyond the limit",
    x = "PM2.5 ATM",
    y = "Frequency"
  ) +
  theme_minimal() +
  scale_y_continuous(labels = scales::comma) + # Make y-axis non-scientific
  xlim(0, 100) # Limit x-axis to 0-100 to better visualize the concentration
```

![](PreprocessingPurpleAirViz_files/figure-gfm/pm25-dist-1.png)<!-- -->

## Plot daily trend for a random day and sensor

```r
# Pick a random sensor and date (full 24 hrs available)
random_sensor_data <- purpleair_filtered %>%
  group_by(date = date(time_stamp), sensor_index) %>%
  filter(n_distinct(hour(time_stamp)) == 24) %>%
  ungroup() %>%
  sample_n(1)

# Get data for random sensor and day
sensor_i_data <- purpleair_filtered %>%
  filter(sensor_index == random_sensor_data$sensor_index) %>%
  filter(date(time_stamp) == random_sensor_data$date)

# Plot the daily trend for the selected sensor
ggplot(sensor_i_data, aes(x = hour(time_stamp), y = pm2.5_atm)) +
  geom_line() +
  labs(
    x = "Hour of the Day",
    y = "PM2.5 ATM",
    title = paste0("PM2.5 for Sensor ", as.integer(random_sensor_data$sensor_index), " on ", random_sensor_data$date)
  ) +
  theme_minimal()
```

![](PreprocessingPurpleAirViz_files/figure-gfm/random-sensor-day-plot-1.png)<!-- -->

## Number of Active Sensors per Month

```r
monthly_sensors <- purpleair_filtered %>%
  mutate(month = format(time_stamp, "%Y-%m")) %>%
  select(sensor_index, month) %>%
  distinct() %>%
  group_by(month) %>%
  summarize(count=n())

ggplot(monthly_sensors, aes(x = month, y = count)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(
    title = "Number of Active Sensors per Month",
    x = "Month",
    y = "Number of Active Sensors"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(hjust = 0.5)
  )
```

![](PreprocessingPurpleAirViz_files/figure-gfm/monthly-sensors-plot-1.png)<!-- -->

## Sensor Activity Distribution

```r
# Summarize the number of active months per sensor
sensor_activity <- purpleair_filtered %>%
  mutate(month = format(time_stamp, "%Y-%m")) %>%
  select(sensor_index, month) %>%
  distinct() %>%
  group_by(sensor_index) %>%
  summarize(active_months = n(), .groups = 'drop')

# Create the cumulative distribution
sensor_activity_distribution <- sensor_activity %>%
  group_by(active_months) %>%
  summarize(count = n(), .groups = 'drop') %>%
  arrange(desc(active_months)) %>%
  mutate(
    cumulative_count = cumsum(count),
    cumulative_percentage = cumulative_count / sum(count) * 100
  )

n_months <- max(sensor_activity_distribution$active_months)

# Plot cumulative distribution
ggplot(sensor_activity_distribution, aes(x = active_months, y = cumulative_count)) +
  geom_line(color = "steelblue") +
  geom_point(color = "steelblue") +
  labs(
    title = "Cumulative Number of Sensors (Number of Active Months)",
    x = "Active Months",
    y = "Number of Sensors"
  ) +
  theme_minimal() +
  scale_y_continuous(limits = c(0, 800), breaks = seq(0, 800, 100)) +
  scale_x_continuous(breaks = scales::pretty_breaks(n = n_months)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

![](PreprocessingPurpleAirViz_files/figure-gfm/cumulative-distribution-plot-1.png)<!-- -->

## Map Sensor Activity

```r
# Join sensor activity data with sensor locations
sensor_activity <- purpleair_filtered %>%
  mutate(month = format(time_stamp, "%Y-%m")) %>%
  select(sensor_index, month) %>%
  distinct() %>%
  group_by(sensor_index) %>%
  summarize(active_months = n(), .groups = 'drop')

activity <- pa_sensors %>% inner_join(sensor_activity, by = "sensor_index")

# Define a color palette
color_palette <- colorNumeric(palette = hcl.colors(24, palette = "Spectral"), domain = activity$active_months)

# Create the leaflet map
leaflet(activity) %>%
  addProviderTiles("CartoDB") %>%
  addCircleMarkers(
    radius = ~active_months / 4,  # Circle size based on the number of active months
    color = ~color_palette(active_months),  # Circle color based on the number of active months
    fillOpacity = 0.7,
    stroke = FALSE,  # No border for the circles
    label = ~paste("Sensor Index:", sensor_index, "<br>Active Months:", active_months)
  ) %>%
  addLegend(
    "bottomright",
    pal = color_palette,
    values = ~active_months,
    title = "Active Months",
    opacity = 1
  )
```

![](PreprocessingPurpleAirViz_files/figure-gfm/sensor-activity-map-1.png)<!-- -->

## Plot random sensors

```r
# Plot 4 random sensors
subset_sensors <- sample(unique(purpleair_filtered$sensor_index), 4)
filtered_data <- purpleair_filtered %>% filter(sensor_index %in% subset_sensors)

# Create the faceted plot
ggplot(filtered_data, aes(x = time_stamp, y = pm2.5_atm, color = sensor_index)) +
  geom_line() +
  labs(
    x = "Date",
    y = "PM2.5 ATM",
    title = "PM2.5 Levels Over Time by Sensor"
  ) +
  facet_wrap(~ sensor_index, scales = "fixed", ncol = 2) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(hjust = 0.5),
    legend.position = "none"
  )
```

![](PreprocessingPurpleAirViz_files/figure-gfm/plot-random-sensors-1.png)<!-- -->

## Map Air Quality Index using average PM2.5

```r
# https://www.epa.gov/sites/default/files/2016-04/documents/2012_aqi_factsheet.pdf
avg_pm25 <- purpleair_filtered %>%
  group_by(sensor_index) %>%
  summarize(avg_pm25 = mean(pm2.5_atm))

# Define the intervals and corresponding colors
intervals <- c(0, 12, 35.4, 55.4, 150.4, 250.4, Inf)
AQI <- c("Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous")

# Create a new column with color intervals
avg_pm25$AQI <- cut(avg_pm25$avg_pm25, breaks = intervals, labels = AQI, include.lowest = TRUE)

pa_avgpm25 <- merge(pa_sensors, avg_pm25, by = "sensor_index")

# Define a color palette function
color_palette <- colorFactor(palette = c("green", "yellow", "orange", "red", "deeppink3", "darkred"),
                             levels = AQI)

# Plot the average PM2.5 for each sensor with leaflet
aqi_map <- leaflet(pa_avgpm25) %>%
  addCircleMarkers(
    radius = 2,
    color = ~color_palette(AQI),
    fillOpacity = 0.7,
    stroke = FALSE,
    label = ~paste("Sensor Index:", sensor_index, "<br>Average PM2.5:", round(avg_pm25, 2), "<br>AQI:", AQI)
  ) %>%
  addProviderTiles("CartoDB") %>%
  addLegend("bottomright", pal = color_palette, values = AQI,
            title = "Air Quality Index", opacity = 1)

aqi_map
```

![](PreprocessingPurpleAirViz_files/figure-gfm/map-AQI-1.png)<!-- -->
