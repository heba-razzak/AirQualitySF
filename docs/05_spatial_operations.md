Spatial Operations
================

Load required libraries

``` r
library(dplyr)         # Data manipulation
library(sf)            # Spatial data manipulation
library(data.table)    # Working with large files
library(tidyr)         # Reshape data
library(geosphere)     # For bearing calculation
library(units)         # Convert units
```

``` r
pa_sensors <- read.csv(file.path("data", "raw", "pa_sensors.csv"))
pa_sf <- st_as_sf(pa_sensors, coords=c("longitude", "latitude"), crs = 4326)
```

Road types: Major and Minor Calculate road lengths for each PurpleAir
sensor

``` r
filepath <- file.path("data", "processed", "roads.csv")
if (!file.exists(filepath)) {
  roads_path <- file.path("data", "raw", "OSM", "bayarea_roads_osm.gpkg")
  roads_sf <- st_read(roads_path, quiet = TRUE) %>% filter(sensor_index %in% unique(pa_sensors$sensor_index))
  
  # https://wiki.openstreetmap.org/wiki/Key:highway
  major_roads <- c("motorway", "motorway_link", "trunk", "primary")
  
  # group road types to major and minor
  osm_roads <- roads_sf %>%
    mutate(osm_id = as.integer(osm_id)) %>%
    mutate(highway = ifelse(is.na(highway), "NA", highway)) %>%
    mutate(road_type = ifelse(highway %in% major_roads, "major", "minor"))
  # Calculate road lengths
  road_lengths <- osm_roads %>%
    select(sensor_index, road_type) %>%
    group_by(sensor_index, road_type) %>%
    summarize(road_length = round(sum(st_length(geom)),2), .groups = 'drop') %>%
    st_drop_geometry()
  
  # Remove units from road_length
  attributes(road_lengths$road_length) = NULL
  
  # Pivot road lengths
  road_lengths_pivot <- road_lengths %>%
    pivot_wider(
      names_from = road_type,
      values_from = road_length,
      values_fill = list(road_length = 0),
      names_prefix = "length_"
    )
  
  fwrite(road_lengths_pivot, filepath)
}
```

Building types: house, apartment, undefined, other Calculate building
areas for each PurpleAir sensor

``` r
filepath <- file.path("data", "processed", "buildings.csv")
if (!file.exists(filepath)) {
  buildings_path <- file.path("data", "raw", "OSM", "bayarea_buildings_osm.gpkg")
  buildings_sf <- st_read(buildings_path, quiet = TRUE) %>% filter(sensor_index %in% unique(pa_sensors$sensor_index))
  
  # https://wiki.openstreetmap.org/wiki/Key:building
  # Define building categories
  house <- c("house", "detached", "semidetached_house", "houses", "farm")
  apartments <- c("residential", "apartment")
  undefined <- c("NA", "yes")
  
  # Categorize buildings
  buildings <- buildings_sf %>% 
    mutate(building = ifelse(is.na(building), "NA", building)) %>%
    mutate(building_type = case_when(
      building %in% undefined ~ "undefined",
      building %in% house ~ "house",
      building %in% apartments ~ "apartment",
      TRUE ~ "other"
    ))
  # building areas in m^2
  building_areas <- buildings %>%
    select(sensor_index, building_type) %>%
    group_by(sensor_index, building_type) %>%
    summarize(building_area = sum(st_area(geom)), .groups = 'drop') %>%
    st_drop_geometry()
  
  # remove units from building_area
  attributes(building_areas$building_area) = NULL
  
  # round area
  building_areas$building_area <- round(building_areas$building_area,2)
  
  # pivot building types
  building_areas <- building_areas %>%
    pivot_wider(names_from = building_type, 
                values_from = building_area, 
                names_prefix = "area_",
                values_fill = list(building_area = 0))
  
  fwrite(building_areas, filepath)
}
```

Calculate num trees for each PurpleAir sensor

``` r
filepath <- file.path("data", "processed", "trees.csv")
if (!file.exists(filepath)) {
  trees_path <- file.path("data", "raw", "OSM", "bayarea_trees_osm.gpkg")
  trees_sf <- st_read(trees_path, quiet = TRUE) %>% filter(sensor_index %in% unique(pa_sensors$sensor_index))
  # Drop geometry and calculate tree counts
  tree_counts <- trees_sf %>% 
    st_drop_geometry() %>%
    select(sensor_index) %>%
    group_by(sensor_index) %>%
    summarize(num_trees = n(), .groups = 'drop')
  
  fwrite(tree_counts, filepath)
}
```

Link Wildfires and PurpleAir sensors by distance, direction, recency

``` r
# Data Source:
# https://data.ca.gov/dataset/california-fire-perimeters-all1
# Metadata (Column Descriptions):
# https://calfire-forestry.maps.arcgis.com/home/item.html?id=93a1f8cc1456497f86ecd25933e6c9b9

# ALARM_DATE Date 8 DD/MM/YYYY format, date of fire discovery
# CONT_DATE Date 8 DD/MM/YYYY format, Containment date for the fire
# GIS_ACRES Float 4 GIS calculated area, in acres

filepath <- file.path("data", "processed", "wildfires.csv")
if (!file.exists(filepath)) {
  # Read purple air data
  filepath <- file.path("data", "raw", "purpleair_2018-01-01_2019-12-31.csv")
  purpleair_data <- read.csv(filepath)
  purpleair_data <- purpleair_data %>% 
    select(-pm2.5_atm, -pm2.5_atm_a, -pm2.5_atm_b, -pm2.5_cf_1, -pm2.5_cf_1_a, -pm2.5_cf_1_b)
  
  # Fire dates: 2018, 2019 (& 5 days before 2018)
  fire <- st_read(
    file.path("data", "raw", "CaliforniaFirePerimeters", "California_Fire_Perimeters_(all).shp"), quiet = TRUE) %>%
    filter(YEAR_ %in% c(2017, 2018, 2019), STATE == "CA") %>% 
    select(ALARM_DATE, CONT_DATE, GIS_ACRES) %>%
    rename(fire_start = ALARM_DATE, fire_end = CONT_DATE, fire_acres = GIS_ACRES) %>%
    filter(fire_start >= as.Date("2018-01-01")-5 | fire_end >= as.Date("2018-01-01")-5) %>%
    mutate(fire_id = row_number())
  
  # Get distances between purpleAir sensors and fires (within 100km)
  pa_sf <- st_transform(pa_sf, st_crs(fire))
  pa_fire_distances <- st_distance(pa_sf, fire, by_element = FALSE)
  distances_df <- as.data.frame(as.table(pa_fire_distances))
  colnames(distances_df) <- c("sensor_index_pos", "fire_id_pos", "fire_distance")
  pa_fire_dist <- distances_df %>%
    mutate(
      sensor_index = pa_sf$sensor_index[sensor_index_pos],
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
  
  sensor_coords <- st_transform(pa_sf, crs = 4326) %>% 
    st_coordinates() %>% as.data.frame() %>% 
    mutate(sensor_index = pa_sf$sensor_index) %>%
    rename(sensor_x = X, sensor_y = Y)
  
  pa_fire_dist <- pa_fire_dist %>%
    left_join(fire_coords, by = "fire_id") %>%
    left_join(sensor_coords, by = "sensor_index")
  
  pa_fire_dist_dir <- pa_fire_dist %>%
    mutate(fire_bearing = bearing(cbind(sensor_x, sensor_y), cbind(fire_x, fire_y)),
           fire_direction = round((fire_bearing + 360) %% 360)) %>%
    select(sensor_index, fire_id, fire_distance, fire_direction)
  
  # Sensor index and active dates
  sensor_dates <- purpleair_data %>% 
    mutate(sensor_date = as.Date(time_stamp)) %>%
    select(sensor_index, sensor_date) %>% distinct()
  
  # Fire info
  fire_df <- fire %>% select(fire_id, fire_start, fire_end, fire_acres) %>% st_drop_geometry()
  
  # Join Purpleair sensors active date and fire info
  purpleair_fires_df <- pa_fire_dist_dir %>%
    left_join(sensor_dates, by = "sensor_index") %>%
    left_join(fire_df, by = "fire_id")
  
  # Create features for fire
  pafire <- purpleair_fires_df %>%
    mutate(fire_days1 = pmax(0, 1 + as.numeric(sensor_date - fire_start)),
           fire_days2 = ifelse(fire_days1 == 0 , 0, 1 + pmax(0,as.numeric(sensor_date - fire_end))),
           active_or_recent_fire = (fire_days2 == 1 | (fire_days2 > 1 & fire_days2 <= 8)),
           fire_distance = round(fire_distance),
           fire_acres = round(fire_acres)) %>% 
    filter(active_or_recent_fire) %>%
    select(sensor_index, sensor_date, fire_id, fire_days1, fire_days2, fire_distance, fire_acres, fire_direction)
  
  ## ADD DISTANCE FILTER ?
  
  # add fire features to dataset
  fire_data <- purpleair_data %>%
    mutate(sensor_date = as.Date(time_stamp)) %>%
    left_join(pafire, by = c("sensor_index" = "sensor_index", "sensor_date" = "sensor_date")) %>%
    select(-sensor_date) %>%
    replace_na(list(fire_days1 = 0, fire_days2 = 0, fire_distance = 0, fire_acres = 0, fire_direction = 0))
  
  fwrite(fire_data, filepath)
}
```

    ## Warning: st_centroid assumes attributes are constant over geometries

    ## Warning in left_join(., sensor_dates, by = "sensor_index"): Detected an unexpected many-to-many relationship between `x` and `y`.
    ## ℹ Row 1 of `x` matches multiple rows in `y`.
    ## ℹ Row 50366 of `y` matches multiple rows in `x`.
    ## ℹ If a many-to-many relationship is expected, set `relationship =
    ##   "many-to-many"` to silence this warning.

    ## Warning in left_join(., pafire, by = c(sensor_index = "sensor_index", sensor_date = "sensor_date")): Detected an unexpected many-to-many relationship between `x` and `y`.
    ## ℹ Row 3818 of `x` matches multiple rows in `y`.
    ## ℹ Row 95190 of `y` matches multiple rows in `x`.
    ## ℹ If a many-to-many relationship is expected, set `relationship =
    ##   "many-to-many"` to silence this warning.
