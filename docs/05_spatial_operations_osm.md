Spatial Operations Open Street Map
================

Load required libraries

``` r
library(dplyr)         # Data manipulation
library(sf)            # Spatial data manipulation
library(data.table)    # Working with large files
library(tidyr)         # Reshape data
```

``` r
pa_sensors <- read.csv(file.path("data", "raw", "pa_sensors.csv"))
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
