Preprocessing PurpleAir
================

# Clean PurpleAir data points

## Load required libraries

``` r
library(dplyr) # For data manipulation
library(data.table) # Faster than dataframes (for big files)
library(ggplot2) # Plots
library(lubridate) # Dates
library(sf) # Shapefiles
library(leaflet) # Interactive maps
```

## Read files

``` r
purpleair_data <- fread(paste0(purpleair_directory, "/purple_air_2018-2019.csv"))
purpleair_sensors <- st_read(paste0(purpleair_directory, "/purpleair_sensors.gpkg"), quiet = TRUE)
```

## Plot of PM2.5 channel A vs B

``` r
ggplot(purpleair_data, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) +
  geom_point() +
  labs(x = "Channel A PM2.5",
       y = "Channel B PM2.5",
       title = "PM2.5 Channel A vs B",
       subtitle = "Axes limits set to 1000; more data points beyond the limit") +
  theme_minimal() +
  xlim(0, 1000) +
  ylim(0, 1000)
```

![](PreprocessingPurpleAir_files/figure-gfm/channel-a-b-plot-1.png)<!-- -->

## Check readings with inconsistencies between channel A and B

``` r
# Define thresholds (absolute difference and maximum pm2.5)
threshold <- 50
maxpm25 <- 2000

# Filter inconsistent data
inconsistent_readings <- purpleair_data %>% 
  filter(abs(pm2.5_atm_a - pm2.5_atm_b) > threshold | pm2.5_atm_a >= maxpm25 | pm2.5_atm_b >= maxpm25)

# Plot inconsistent readings
ggplot(inconsistent_readings, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) +
  geom_point() +
  labs(
    x = "Channel A PM2.5",
    y = "Channel B PM2.5",
    title = "Inconsistencies Between Channel A and B",
    subtitle = "Axes limits set to 1000; more data points beyond the limit"
  ) +
  theme_minimal() +
  xlim(0, 1000) +
  ylim(0, 1000)
```

![](PreprocessingPurpleAir_files/figure-gfm/inconsistent-purpleair-1.png)<!-- -->

## Filter out inconsistencies

``` r
# Filter out rows where absolute difference is greater than threshold & PM2.5 < maximum
purpleair_filtered <- purpleair_data %>%
  filter(abs(pm2.5_atm_a - pm2.5_atm_b) <= threshold & pm2.5_atm_a < maxpm25 & pm2.5_atm_b < maxpm25)

ggplot(purpleair_filtered, aes(x = pm2.5_atm_a, y = pm2.5_atm_b)) +
  geom_point() +
  labs(x = "Channel A PM2.5",
       y = "Channel B PM2.5",
       title = "PM2.5 Channel A vs B After Filtering") +
  theme_minimal()
```

![](PreprocessingPurpleAir_files/figure-gfm/filtered-purpleair-1.png)<!-- -->

``` r
# Remove unnecessary columns
purpleair_filtered <- purpleair_filtered %>% select(-pm2.5_atm_a, -pm2.5_atm_b)
```

## Remove Sensors

### Faulty: More than 40% of readings are zeros

### Not Enough Data: Less than 0.5% of data available for our date range

``` r
# Generate the number of hours in date range
start_time <- min(purpleair_filtered$time_stamp, na.rm = TRUE)
end_time <- max(purpleair_filtered$time_stamp, na.rm = TRUE)
n_timestamps <- length(seq(from = start_time, to = end_time, by = "hour"))

# Available data for each sensor
avail_data <- purpleair_filtered %>%
  group_by(sensor_index) %>%
  summarize(avail_data_percent = round(100 * n() / n_timestamps, 2)) %>%
  arrange(avail_data_percent)

# Remove sensors with less than 0.5% data
sensors_missing_data <- avail_data %>% filter(avail_data_percent < 0.5)
purpleair_filtered <- purpleair_filtered %>%
  filter(!sensor_index %in% sensors_missing_data$sensor_index)

# Percentage of zero readings for each sensor
sensor_zero_readings <- purpleair_filtered %>%
  group_by(sensor_index) %>%
  summarize(percent_zeros = round(100 * sum(pm2.5_atm == 0) / n(), 2)) %>% 
  arrange(desc(percent_zeros))

# Remove sensors with high percentage of zero readings (>40%)
sensors_high_zeros <- sensor_zero_readings %>% filter(percent_zeros > 40)
purpleair_filtered <- purpleair_filtered %>%
  filter(!sensor_index %in% sensors_high_zeros$sensor_index)
```

## Save Filtered Data to CSV

``` r
# Save filtered data
write.csv(purpleair_filtered, file = file.path(preprocessing_directory, "purpleair_filtered_2018-2019.csv"), row.names = FALSE)
```

# Visualizations

## Dataset info

    ## Number of Sensors:  646 
    ## 
    ##  Date Range:  2018-01-01  to  2019-12-31

``` r
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

![](PreprocessingPurpleAir_files/figure-gfm/pm25-dist-1.png)<!-- -->

## Plot daily trend for a random day and sensor

``` r
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

![](PreprocessingPurpleAir_files/figure-gfm/random-sensor-day-plot-1.png)<!-- -->

## Number of Active Sensors per Month

``` r
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

![](PreprocessingPurpleAir_files/figure-gfm/monthly-sensors-plot-1.png)<!-- -->

## Sensor Activity Distribution

``` r
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

![](PreprocessingPurpleAir_files/figure-gfm/cumulative-distribution-plot-1.png)<!-- -->

## Map Sensor Activity

``` r
# Join sensor activity data with sensor locations
sensor_activity <- purpleair_filtered %>%
  mutate(month = format(time_stamp, "%Y-%m")) %>%
  select(sensor_index, month) %>%
  distinct() %>%
  group_by(sensor_index) %>%
  summarize(active_months = n(), .groups = 'drop')

activity <- purpleair_sensors %>% inner_join(sensor_activity, by = "sensor_index")

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

![](PreprocessingPurpleAir_files/figure-gfm/sensor-activity-map-1.png)<!-- -->

## Plot random sensors

``` r
# Plot 4 random sensors
subset_sensors <- sample(unique(purpleair_filtered$sensor_index), 4)
filtered_data <- purpleair_filtered %>% filter(sensor_index %in% subset_sensors)

# Create the faceted plot
ggplot(filtered_data, aes(x = time_stamp, y = pm2.5_atm, color = as.factor(sensor_index))) +
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

![](PreprocessingPurpleAir_files/figure-gfm/plot-random-sensors-1.png)<!-- -->

## Map Air Quality Index using average PM2.5

``` r
# https://www.epa.gov/sites/default/files/2016-04/documents/2012_aqi_factsheet.pdf
avg_pm25 <- purpleair_filtered %>%
  group_by(sensor_index) %>%
  summarize(avg_pm25 = mean(pm2.5_atm))

# Define the intervals and corresponding colors
intervals <- c(0, 12, 35.4, 55.4, 150.4, 250.4, Inf)
AQI <- c("Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous")

# Create a new column with color intervals
avg_pm25$AQI <- cut(avg_pm25$avg_pm25, breaks = intervals, labels = AQI, include.lowest = TRUE)

pa_avgpm25 <- merge(purpleair_sensors, avg_pm25, by = "sensor_index")

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

![](PreprocessingPurpleAir_files/figure-gfm/map-AQI-1.png)<!-- -->
