Wildfires
================

# Wildfires

## Load required libraries

``` r
library(data.table)
library(tidyr)
library(dplyr)      # Data manipulation
library(units)      # convert units
library(sf)         # Spatial data manipulation
library(geosphere)  # For bearing calculation
```

``` r
# Data Source:
# https://data.ca.gov/dataset/california-fire-perimeters-all1
# Metadata (Column Descriptions):
# https://calfire-forestry.maps.arcgis.com/home/item.html?id=93a1f8cc1456497f86ecd25933e6c9b9

# ALARM_DATE Date 8 DD/MM/YYYY format, date of fire discovery
# CONT_DATE Date 8 DD/MM/YYYY format, Containment date for the fire
# GIS_ACRES Float 4 GIS calculated area, in acres

# purpleair dataset dates
dataset <- fread(file.path(preprocessing_directory, "final_dataset.csv"))
startdt = as.Date(min(dataset$time_stamp))
enddt = as.Date(max(dataset$time_stamp))

# fire dates: 2018, 2019 (& 3 days before 2018)
fire <- st_read(
  file.path(preprocessing_directory, "CaliforniaFirePerimeters",
            "California_Fire_Perimeters_(all).shp"), quiet = TRUE) %>%
  filter(YEAR_ %in% c(2017, 2018, 2019), STATE == "CA") %>% 
  select(ALARM_DATE, CONT_DATE, GIS_ACRES) %>%
  rename(fire_start = ALARM_DATE, fire_end = CONT_DATE, fire_acres = GIS_ACRES) %>%
  filter(fire_start >= startdt-5 | fire_end >= startdt-5) %>%
  mutate(fire_id = row_number())

# purpleair sensor locations
purpleair_sensors <- st_read(file.path(
  preprocessing_directory, "pasensors_weatherstations.gpkg"), quiet = TRUE)
purpleair_sensors <- st_transform(purpleair_sensors, st_crs(fire))
```

## purple air to fire distance and direction

``` r
# Get distances between purpleAir sensors and fires (within 100km)
pa_fire_distances <- st_distance(purpleair_sensors, fire, by_element = FALSE)
distances_df <- as.data.frame(as.table(pa_fire_distances))
colnames(distances_df) <- c("sensor_index_pos", "fire_id_pos", "fire_distance")
pa_fire_dist <- distances_df %>%
  mutate(
    sensor_index = purpleair_sensors$sensor_index[sensor_index_pos],
    fire_id = fire$fire_id[fire_id_pos]
  ) %>%
  select(sensor_index, fire_id, fire_distance) %>%
  mutate(fire_distance = drop_units(fire_distance)) %>% 
  filter(fire_distance <= 100000)

# Extract fire and sensor coordinates
fire_coords <- st_make_valid(fire) %>%  st_transform(crs = 4326) %>% 
  st_centroid() %>% st_coordinates() %>%  as.data.frame() %>% 
  mutate(fire_id = fire$fire_id) %>% select(fire_id, X, Y) %>%
  rename(fire_x = X, fire_y = Y)
```

    ## Warning: st_centroid assumes attributes are constant over geometries

``` r
sensor_coords <- st_transform(purpleair_sensors, crs = 4326) %>% 
  st_coordinates() %>% as.data.frame() %>% 
  mutate(sensor_index = purpleair_sensors$sensor_index) %>%
  rename(sensor_x = X, sensor_y = Y)

pa_fire_dist <- pa_fire_dist %>%
  left_join(fire_coords, by = "fire_id") %>%
  left_join(sensor_coords, by = "sensor_index")

pa_fire_dist_dir <- pa_fire_dist %>%
  mutate(fire_bearing = bearing(cbind(sensor_x, sensor_y), cbind(fire_x, fire_y)),
         fire_direction = round((fire_bearing + 360) %% 360)) %>%
  select(sensor_index, fire_id, fire_distance, fire_direction)
```

## joining purple air and fires by distance and dates

``` r
# Sensor index and active dates
sensor_dates <- dataset %>% 
  mutate(sensor_date = as.Date(time_stamp)) %>%
  select(sensor_index, sensor_date) %>% distinct()

# Fire info
fire_df <- fire %>% select(fire_id, fire_start, fire_end, fire_acres) %>% st_drop_geometry()

# Join Purpleair sensors active date and fire info
purpleair_fires_df <- pa_fire_dist_dir %>%
  left_join(sensor_dates, by = "sensor_index") %>%
  left_join(fire_df, by = "fire_id")
```

    ## Warning in left_join(., sensor_dates, by = "sensor_index"): Detected an unexpected many-to-many relationship between `x` and `y`.
    ## ℹ Row 1 of `x` matches multiple rows in `y`.
    ## ℹ Row 10936 of `y` matches multiple rows in `x`.
    ## ℹ If a many-to-many relationship is expected, set `relationship =
    ##   "many-to-many"` to silence this warning.

``` r
# Create features for fire
pafire <- purpleair_fires_df %>%
  mutate(fire_days1 = pmax(0, 1 + as.numeric(sensor_date - fire_start)),
         fire_days2 = ifelse(fire_days1 == 0 , 0, 1 + pmax(0,as.numeric(sensor_date - fire_end))),
         active_or_recent_fire = (fire_days2 == 1 | (fire_days2 > 1 & fire_days2 <= 8)),
         fire_distance = round(fire_distance),
         fire_acres = round(fire_acres)) %>% 
  filter(active_or_recent_fire) %>%
  select(sensor_index, sensor_date, fire_days1, fire_days2, fire_distance, fire_acres, fire_direction)

# add fire features to dataset
dataset <- dataset %>%
  mutate(sensor_date = as.Date(time_stamp)) %>%
  left_join(pafire, by = c("sensor_index" = "sensor_index", "sensor_date" = "sensor_date")) %>%
  select(-sensor_date) %>%
  replace_na(list(fire_days1 = 0, fire_days2 = 0, fire_distance = 0, fire_acres = 0, fire_direction = 0))
```

    ## Warning in left_join(., pafire, by = c(sensor_index = "sensor_index", sensor_date = "sensor_date")): Detected an unexpected many-to-many relationship between `x` and `y`.
    ## ℹ Row 164474 of `x` matches multiple rows in `y`.
    ## ℹ Row 73022 of `y` matches multiple rows in `x`.
    ## ℹ If a many-to-many relationship is expected, set `relationship =
    ##   "many-to-many"` to silence this warning.

``` r
fwrite(dataset, paste0(preprocessing_directory,"/final_dataset_fire.csv"))
```
