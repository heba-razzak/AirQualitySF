Download OSM data
================

Load required libraries

``` r
library(osmdata)       # Download OpenStreetMap Data
library(dplyr)         # Data manipulation
library(data.table)    # Working with large files
library(sf)            # Spatial data manipulation
library(leaflet)       # Interactive maps
library(tigris)        # Counties map data
library(ggplot2)       # Data visualization
library(htmlwidgets)   # Creating HTML widgets
library(webshot)       # Convert URL to image
```

Create 1 km octagon buffers around Purple Air Sensors

``` r
# Reproject to California Albers (meters) for buffering
pa_sf <- st_transform(pa_sf, 3310)

# Create 1 km buffers (octagons) around sensors
purpleairs_buffers <- st_buffer(pa_sf, dist=1000, nQuadSegs=2)

# Reproject back to lat/lon for mapping
pa_sf <- st_transform(pa_sf, 4326)
purpleairs_buffers <- st_transform(purpleairs_buffers, 4326)
```

Map PurpleAir Sensors with Buffers

``` r
img_path <- file.path("../docs", "plots", "pa-buffer-map.png")
if (!file.exists(img_path)) {
  map_path <- file.path("../docs", "maps", "pa-buffer-map.html")
  m <- leaflet() %>%
    addPolygons(data = purpleairs_buffers, 
                popup = ~paste("sensor_index:", sensor_index), 
                label = ~paste("sensor_index:", sensor_index),
                color = "#AA44AA", opacity = 0.5, weight = 1,
                fillColor = "#dec9e9", fillOpacity = 0.2) %>%
    addCircleMarkers(data = pa_sf, 
                     popup = ~paste("sensor_index:", sensor_index), 
                     label = ~paste("sensor_index:", sensor_index),
                     color = "#AA44AA", weight = 2, radius = 1) %>%
    addProviderTiles("CartoDB") %>%
    setView(lng = -122.4194, lat = 37.7749, zoom = 12)
  saveWidget(m, file = map_path)
  webshot(map_path, file = img_path)
}

knitr::include_graphics(img_path)
```

<img src="../docs/plots/pa-buffer-map.png" width="992" />

Download OSM Roads

``` r
filepath <- file.path("data", "raw", "bayarea_osm_roads.gpkg")

if (!file.exists(filepath)) {
  # Download OSM roads data for each sensor buffer
  for (i in 1:nrow(purpleairs_buffers)) {
    output_name <- paste0("sensor", purpleairs_buffers$sensor_index[i], "_osm_roads.gpkg")
    filename <- file.path("data", "raw", "OSM", output_name)
    
    if (file.exists(filename)) next
    
    osm <- opq(bbox = purpleairs_buffers[i, ]$geom) %>%
      add_osm_feature(key = 'highway') %>%
      osmdata_sf()
    
    if (is.null(osm$osm_lines) || nrow(osm$osm_lines) == 0) next
    
    # If OSM id is missing, fill with row names
    if(!"osm_id" %in% names(osm$osm_lines)) {
      osm$osm_lines$osm_id <- rownames(osm$osm_lines)
    }
    
    # If other column is missing, fill with NA
    cols <- c("name", "highway", "lanes", "maxspeed")
    for (c in cols) {
      if(!c %in% names(osm$osm_lines)) {
        osm$osm_lines[[c]] <- NA
      }
    }
    
    selected_columns <- osm$osm_lines %>%
      select(osm_id, name, highway, lanes, maxspeed)
    
    # Intersect with buffer
    sf_obj <- st_intersection(st_as_sf(selected_columns), purpleairs_buffers[i, ]$geom)
    
    if (is.null(sf_obj) || nrow(sf_obj) == 0) next
    
    sf_obj$sensor_index <- purpleairs_buffers$sensor_index[i]
    st_write(sf_obj, filename, driver = "GPKG", append = FALSE, quiet = TRUE)
  }
  
  # Save OSM road data for sensors into a single file
  file_paths <- list.files(file.path("data", "raw", "OSM"), pattern = "^sensor.*_osm_roads\\.gpkg$", full.names = TRUE)
  sf_list <- lapply(file_paths, st_read, quiet = TRUE)
  merged_sf <- do.call(rbind, sf_list) %>% distinct()
  st_write(merged_sf, filepath, driver = "GPKG", append = FALSE, quiet = TRUE)
}
```

Download OSM Landuse, Natural, Leisure, Boundary

``` r
filepath <- file.path("data", "raw", "bayarea_osm_land.gpkg")

process_polygons <- function(osm_data, osm_key, geom) {
  if (!is.null(osm_data) && nrow(osm_data) > 0) {
    osm_data <- st_make_valid(st_cast(osm_data, "POLYGON"))
    osm_data$osm_id <- ifelse("osm_id" %in% names(osm_data), osm_data$osm_id, rownames(osm_data))
    osm_data$name <- ifelse("name" %in% names(osm_data), osm_data$name, NA)
    osm_data[[osm_key]] <- ifelse(osm_key %in% names(osm_data), osm_data[[osm_key]], NA)
    if (osm_key == "boundary") {
      osm_data <- osm_data %>% filter(boundary %in% c("national_park", "protected_area"))
    }
    osm_data <- osm_data %>% mutate(osm_value = osm_data[[osm_key]], osm_key = osm_key) %>%
      select(osm_id, osm_value, osm_key, name) %>%
      st_intersection(geom)
    return(osm_data)
  }
  return(NULL)
}

if (!file.exists(filepath)) {
  osm_keys <- c("landuse", "natural", "leisure", "boundary")
  all_land_data <- NULL
  for (i in 1:nrow(purpleairs_buffers)) {
    sensor_index <- purpleairs_buffers$sensor_index[i]
    land_data <- NULL
    for (osm_key in osm_keys) {
      bb <- purpleairs_buffers[i, ]$geom
      # Download OSM data for each key
      osm <- opq(bbox = bb) %>%
        add_osm_feature(key = osm_key) %>%
        osmdata_sf()
      # Combine polygons and multipolygons
      osm_p <- process_polygons(osm$osm_polygons, osm_key, bb)
      osm_mp <- process_polygons(osm$osm_multipolygons, osm_key, bb)
      key_data <- rbind(osm_p, osm_mp)
      land_data <- rbind(land_data, key_data)
    }
    if (is.null(land_data) || nrow(land_data) == 0) next 
    land_data <- land_data %>% 
      mutate(sensor_index = sensor_index) %>%
      select(sensor_index, osm_id, osm_value, osm_key, name) 
    all_land_data <- rbind(all_land_data, land_data)
  }
  st_write(all_land_data, filepath, driver = "GPKG", append = FALSE, quiet = TRUE)
}
```

<!-- ```{r} -->
<!-- osmpol <- osm$osm_polygons  %>% filter(is.na(access) | access != "private") -->
<!-- osmpolprivate <- osm$osm_polygons %>% filter(access == "private") -->
<!-- # %>% filter(osm_id == 51492576) -->
<!-- osmmultipol <- osm$osm_multipolygons -->
<!-- osmmultipol2 <- st_make_valid(st_cast(osm$osm_multipolygons, "POLYGON")) -->
<!-- # %>% filter(osm_id == 51492576) -->
<!-- osmpol %>% filter(osm_id == 805117307) -->
<!-- m <- leaflet() %>% -->
<!--     addPolygons(data = purpleairs_buffers %>% filter(sensor_index == 767), -->
<!--               popup = ~paste("sensor_index:", sensor_index), -->
<!--               label = ~paste("sensor_index:", sensor_index), -->
<!--               color = "black", opacity = 1, weight = 1, -->
<!--               fillOpacity = 0) %>% -->
<!--       addPolygons(data = osmpol, -->
<!--               popup = ~paste(name, "osm_id:", osm_id), -->
<!--               label = ~paste(name, "osm_id:", osm_id), -->
<!--               color = "#ff595e", opacity = 0.5, weight = 2, fillColor = "#ff595e", fillOpacity = 0) %>% -->
<!--   addPolygons(data = osmpolprivate, -->
<!--               popup = ~paste(name, "osm_id:", osm_id), -->
<!--               label = ~paste(name, "osm_id:", osm_id), -->
<!--               color = "#1982c4", opacity = 1, weight = 2, fillColor = "#1982c4", fillOpacity = 0) %>% -->
<!--   # addPolygons(data = osmmultipol, -->
<!--   #             popup = ~paste(name, "osm_id:", osm_id), -->
<!--   #             label = ~paste(name, "osm_id:", osm_id), -->
<!--   #             color = "#1982c4", opacity = 0.5, weight = 2, fillColor = "#1982c4", fillOpacity = 0) %>% -->
<!--     addPolygons(data = osmmultipol2, -->
<!--               popup = ~paste(name, "osm_id:", osm_id), -->
<!--               label = ~paste(name, "osm_id:", osm_id), -->
<!--               color = "#8ac926", opacity = 0.5, weight = 2, fillColor = "#8ac926", fillOpacity = 0) %>% -->
<!--   addProviderTiles("CartoDB") -->
<!-- m -->
<!-- ``` -->
<!-- ```{r} -->
<!-- filepath <- file.path("data", "raw", "bayarea_osm_roads.gpkg") -->
<!-- osm_roads <- st_read(filepath) -->
<!-- # filepath <- file.path("data", "raw", "bayarea_osm_land_no_intersection.gpkg") -->
<!-- filepath <- file.path("data", "raw", "bayarea_osm_land.gpkg") -->
<!-- osm_land <- st_read(filepath) -->
<!-- keysss <- osm_land %>% st_drop_geometry() %>% select(land, key) %>% distinct() %>% arrange(key, land) -->
<!-- ``` -->
<!-- ```{r} -->
<!-- bbox <- c(xmin = -122.5, ymin = 37.8, xmax = -122.4, ymax = 37.7) -->
<!-- bbox_polygon <- st_as_sfc(st_bbox(bbox)) -->
<!-- st_crs(bbox_polygon) <- 4326 -->
<!-- sanfran_sensors <- st_intersection(pa_sf, bbox_polygon) -->
<!-- sf_roads <- osm_roads %>% filter(sensor_index %in% unique(sanfran_sensors$sensor_index)) -->
<!-- sf_land <- osm_land %>% filter(sensor_index %in% unique(sanfran_sensors$sensor_index)) -->
<!-- # "landuse", "natural", "leisure", "boundary" -->
<!-- thiskey = "natural" -->
<!-- notthis <- osm_land %>% filter(key != thiskey) -->
<!-- onlythis <- osm_land %>% filter(key == thiskey, (!osm_id %in% notthis$osm_id)) -->
<!-- # onlythis <- osm_land %>% filter(key == thiskey, (!osm_id %in% notthis$osm_id), land %in% c("national_park", "protected_area")) -->
<!-- # onlythis <- osm_land %>% filter(key == thiskey, land %in% c("hazard")) -->
<!-- mapview(onlythis) -->
<!-- # only landuse: 46,642 -->
<!-- # only natural: 25703 -->
<!-- # only leisure: 59,877 -->
<!-- # only boundary: 247 boundary (national_park,protected_area,hazard) -->
<!-- x <- osm_p -->
<!-- x2 <- osm_mp -->
<!-- # 829462466 -->
<!-- osm_p %>% filter(osm_id == "829462466") -->
<!-- osm_mp %>% filter(osm_id == "829462466") -->
<!-- landuseorleisure <- osm_land %>% filter(key %in% c("landuse", "leisure")) -->
<!-- onlynatural <- osm_land %>%  -->
<!--   select(osm_id, land, key) %>% -->
<!--   filter(key == "natural", (!osm_id %in% landuseorleisure$osm_id)) %>% -->
<!--   st_make_valid() %>%  -->
<!--   distinct(osm_id, .keep_all = TRUE) -->
<!-- onlyboundary <- osm_land %>% filter(key == "boundary", (!osm_id %in% landuseorleisure$osm_id), -->
<!--                                     land %in% c("national_park", "protected_area")) %>% -->
<!--   distinct(osm_id, .keep_all = TRUE) -->
<!-- mapview(onlynatural, col.regions = "green", alpha.regions = 0.5) + mapview(onlyboundary, col.regions = "blue", alpha.regions = 0.5) -->
<!-- ``` -->
<!-- ```{r, station2s-map} -->
<!-- filepath <- file.path("data", "raw", "bayarea_osm_land_no_intersection.gpkg") -->
<!-- osm_land <- st_read(filepath) -->
<!-- # c("landuse", "natural", "leisure", "boundary") -->
<!-- # osm_land -->
<!-- landuse <- osm_land %>% filter(key == "landuse") # 47,956 -->
<!-- natural <- osm_land %>% filter(key == "natural") # 26,543 -->
<!-- leisure <- osm_land %>% filter(key == "leisure") # 61,882 -->
<!-- boundary <- osm_land %>%  -->
<!--   filter(key == "boundary",  -->
<!--                                 land %in% c("national_park", "protected_area"), -->
<!--                                 (!osm_id %in% c(8841133, 8838432))) %>% -->
<!--   select(-sensor_index) %>% -->
<!--   st_make_valid() %>% -->
<!--   distinct() -->
<!-- pools <- osm_land %>% filter(key == "leisure", land == "swimming_pool")  -->
<!-- m <- leaflet() %>% -->
<!--   addPolygons(data = purpleairs_buffers, -->
<!--               popup = ~paste("sensor_index:", sensor_index), -->
<!--               label = ~paste("sensor_index:", sensor_index), -->
<!--               color = "#d9dcd6", opacity = 0.5, weight = 1, -->
<!--               fillOpacity = 0) %>% -->
<!--   addPolygons(data = pools,  -->
<!--               popup = ~paste(land, "osm_id:", osm_id),  -->
<!--               label = ~paste(land, "osm_id:", osm_id), -->
<!--               color = "#ff595e", opacity = 0.5, weight = 2, fillColor = "#ff595e", fillOpacity = 0.5) %>% -->
<!--   addProviderTiles("CartoDB") -->
<!-- boundary_pa <- st_intersection(boundary, purpleairs_buffers) -->
<!-- m <- leaflet() %>% -->
<!--   addPolygons(data = purpleairs_buffers, -->
<!--               popup = ~paste("sensor_index:", sensor_index), -->
<!--               label = ~paste("sensor_index:", sensor_index), -->
<!--               color = "#d9dcd6", opacity = 0.5, weight = 1, -->
<!--               fillOpacity = 0) %>% -->
<!--   addPolygons(data = boundary_pa,  -->
<!--               popup = ~paste(land, "osm_id:", osm_id),  -->
<!--               label = ~paste(land, "osm_id:", osm_id), -->
<!--               color = "#ff595e", opacity = 0.5, weight = 2, fillColor = "#ff595e", fillOpacity = 0.5) %>% -->
<!--   addProviderTiles("CartoDB") -->
<!-- m -->
<!-- ``` -->
<!-- ```{r, stations2-map} -->
<!-- # # save map as html -->
<!-- # saveWidget(m, file = map_path) -->
<!-- #  -->
<!-- # # save html as image -->
<!-- # webshot(map_path, file = img_path) -->
<!-- # knitr::include_graphics(img_path) -->
<!-- ``` -->

Highway meanings <https://taginfo.openstreetmap.org/keys/highway#values>
<https://taginfo.geofabrik.de/north-america:us:california:norcal/keys/landuse#overview>

Get highway colors from osm to split them

Download Land Use

natural: scrub, wood, landuse: residential, industrial, farmland
boundary: protected_area leisure: park waterway: stream check what to
get from here
<https://www.openstreetmap.org/relation/13070397#map=14/37.68559/-122.42435>
<https://osmlanduse.org/#10.716666666666669/-122.21682/37.73751/0/> OSM
keys used for classification Classification of the landuse/landcover
classes are similar to the classification level 2 of the CORINE
Landcover classes. The following OSM keys were used to form the
respective class:

1.1. Urban Fabric residential, garages

1.2. Industrial, commercial and transport units railway, industrial,
commercial, retail, harbour, port, lock, marina

1.3. Mine, dump and construction sites quarry, construction, landfill,
brownfield

1.4. Artificial, non-agricultural vegetated areas stadium,
recreation_ground, golf_course, sports_center, playground pitch,
village_green, allotments, cemetery, park, zoo, track, garden, raceway

2.1. Arable Land greenhouse_horticulture, greenhouse, farmland, farm,
farmyard

2.2. Permanent Crops vineyard, orchard

2.3. Pastures meadow

3.1. Forests forest, wood

3.2. Shrub and/or herbaceous vegetation associations grass, greenfield,
scrub, heath, grassland

3.3. Open spaces with little or no vegetation cliff, fell, sand, scree,
beach, mud, glacier, rock

4.1. Inland wetlands marsh, wetland

4.2. Coastal wetlands salt_pond, tidal

5.  Water bodies water, riverbank, reservoir, basin, dock, canal, pond

<!-- -->

    # # bay area
    # bbox <- c(xmin = -123.8, ymin = 36.9, xmax = -121.0, ymax = 39.0)

    # tiny bbox
    bbox <- c(xmin = -122.46, ymin = 37.76, xmax = -122.42, ymax = 37.72)

    bbox_sf <- st_as_sfc(st_bbox(bbox))
    st_crs(bbox_sf) <- 4326

    landuse_sf <- opq(bbox = bbox_sf) %>%
    add_osm_feature(key = "landuse") %>%
    osmdata_sf()

    leisure_sf <- opq(bbox = bbox_sf) %>%
    add_osm_feature(key = "leisure") %>%
    osmdata_sf()

    waterway_sf <- opq(bbox = bbox_sf) %>%
    add_osm_feature(key = "waterway") %>%
    osmdata_sf()

    natural_sf <- opq(bbox = bbox_sf) %>%
    add_osm_feature(key = "natural") %>%
    osmdata_sf()

    boundary_sf <- opq(bbox = bbox_sf) %>%
    add_osm_feature(key = "boundary") %>%
    osmdata_sf()

    # Convert all downloaded data to sf objects for visualization
    landuse_pol <- st_as_sf(landuse_sf$osm_polygons) %>% select(osm_id, landuse)
    landuse_mpol <- st_as_sf(landuse_sf$osm_multipolygons) %>% select(osm_id, landuse)
    # leisure_sf_sf <- st_as_sf(leisure_sf$osm_polygons)
    # waterway_sf_sf <- st_as_sf(waterway_sf$osm_lines)
    # natural_sf_sf <- st_as_sf(natural_sf$osm_polygons)

    x <- as.data.frame(landuse_sf_sf)
    x %>% 
    group_by(landuse) %>%
    summarise(count = n()) %>%
    arrange(desc(count))

    osmids <- x %>% filter(is.na(landuse)) %>% mutate(osm_id = as.numeric(osm_id)) %>% pull(osm_id)

    # node, way, or relation
    osmObj <- opq_osm_id(type = "node", id = osmids) %>%
    opq_string() %>%
    osmdata_sf()

    osmObj$osm_points

    colnames(x)

    unique(x$landuse)

    x2 <- x %>% select(where(~ sum(is.na(.)) / nrow(x) < 0.9))

    library(DataOverviewR)

    data_dictionary(x2)

    img_path <- file.path("../docs", "plots", "landuse-map.png")
    if (!file.exists(img_path)) {
    map_path <- file.path("../docs", "maps", "landuse-map.html")
    m <- leaflet() %>%
    addCircleMarkers(data = pa_sf, color = "#AA44AA", weight = 1, radius = 1) %>%
    addPolygons(data = purpleairs_buffers,
    color = "#AA44AA", opacity = 0.5, weight = 1,
    fillColor = "#AA44AA", fillOpacity = 0.2) %>%
    addPolygons(data = landuse_sf_sf,
    color = "#4682B4", opacity = 0.5, weight = 1,
    fillColor = "#4682B4", fillOpacity = 0.2) %>%
    addProviderTiles("CartoDB") %>%
    setView(lng = -122.4194, lat = 37.7749, zoom = 12)
    saveWidget(m, file = map_path)
    webshot(map_path, file = img_path)
    }

    knitr::include_graphics(img_path)


    # Plot all features together
    ggplot() +
    geom_sf(data = natural_sf_sf, fill = "green", alpha = 0.4, color = NA) +
    geom_sf(data = landuse_sf_sf, fill = "blue", alpha = 0.4, color = NA) +
    geom_sf(data = boundary_sf_sf, fill = "purple", alpha = 0.4, color = NA) +
    geom_sf(data = leisure_sf_sf, fill = "yellow", alpha = 0.4, color = NA) +
    geom_sf(data = waterway_sf_sf, color = "cyan", size = 0.5) +
    theme_minimal() +
    labs(title = "Natural and Land Use Features in San Francisco")

    leaflet() %>%
    addTiles() %>%
    addPolygons(data = natural_sf_sf, fillColor = "#228B22", fillOpacity = 0.4, color = NA) %>%
    addPolygons(data = landuse_sf_sf, fillColor = "#4682B4", fillOpacity = 0.4, color = NA) %>%
    addPolygons(data = boundary_sf_sf, fillColor = "#800080", fillOpacity = 0.4, color = NA) %>%
    addPolygons(data = leisure_sf_sf, fillColor = "#FFD700", fillOpacity = 0.4, color = NA) %>%
    addPolylines(data = waterway_sf_sf, color = "#00FFFF", weight = 1) %>%
    addProviderTiles("CartoDB.Positron") %>%
    addLegend(
    position = "bottomright",
    colors = c("#228B22", "#4682B4", "#800080", "#FFD700", "#00FFFF"),
    labels = c("Natural", "Landuse", "Boundary", "Leisure", "Waterway"),
    title = "Features"
    )

Map of OpenStreetMap Roads

``` r
# img_path <- file.path("../docs", "plots", "roads-map.png")
# if (!file.exists(img_path)) {
#   bayarea_roads <- st_read(file.path("data", "raw", "bayarea_roads_osm.gpkg"), quiet = TRUE)
#   map_path <- file.path("../docs", "maps", "roads-map.html")
#   m <- leaflet() %>%
#     addPolylines(data = bayarea_roads, 
#                  color = "#DD94A1", opacity = 0.5, weight = 1) %>%
#     addProviderTiles("CartoDB") %>%
#     setView(lng = -122.4194, lat = 37.7749, zoom = 12)
#   saveWidget(m, file = map_path)
#   webshot(map_path, file = img_path)
# }
# knitr::include_graphics(img_path)
```

Map of OpenStreetMap Buildings

    # ```{r, plot-buildings, results = FALSE}
    "#D7D0CA"

    bayarea_buildings <- st_read(file.path("data", "raw", "bayarea_buildings_osm.gpkg"), quiet = TRUE)
    ca <- counties("California", cb = TRUE, progress_bar=FALSE)

    ggplot() + 
    geom_sf(data = ca, color="black", fill="antiquewhite", size=0.25) +
    geom_sf(data = bayarea_buildings, color="darkorange3", fill = "darkorange") +
    coord_sf(xlim = c(-123.8, -121.0), ylim = c(36.9, 39.0)) +
    theme(panel.background = element_rect(fill = "aliceblue")) + 
    xlab("Longitude") + ylab("Latitude") +
    ggtitle("OSM Buildings")

Map of OpenStreetMap Trees

    # ```{r, plot-trees, results = FALSE} -->
    bayarea_trees <- st_read(file.path("data", "raw", "bayarea_trees_osm.gpkg"), quiet = TRUE)
    ca <- counties("California", cb = TRUE, progress_bar=FALSE)

    ggplot() + 
    geom_sf(data = ca, color="black", fill="antiquewhite", size=0.25) +
    geom_sf(data = bayarea_trees, color = "darkgreen", fill="forestgreen", size = 0.1) +
    coord_sf(xlim = c(-123.8, -121.0), ylim = c(36.9, 39.0)) +
    theme(panel.background = element_rect(fill = "aliceblue")) + 
    xlab("Longitude") + ylab("Latitude") +
    ggtitle("OSM Trees")

    ## Select small area of San Francisco to map

    bbox <- c(xmin = -122.46, ymin = 37.76, xmax = -122.42, ymax = 37.72)
    bbox_polygon <- st_as_sfc(st_bbox(bbox))
    st_crs(bbox_polygon) <- 4326
    sanfran_roads <- st_intersection(bayarea_roads, bbox_polygon)
    sanfran_buildings <- st_intersection(bayarea_buildings, bbox_polygon)
    sanfran_trees <- st_intersection(bayarea_trees, bbox_polygon)
    sanfran_sensors <- st_intersection(filtered_sensors, bbox_polygon)
    sanfran_buffers <- st_intersection(purpleairs_buffers, bbox_polygon)


    ## Plot san fran city
    leaflet() %>%
    # addPolylines(data = bbox_polygon, color = "black", weight = 3, opacity = 1, popup = "Bounding Box") %>%
    addPolylines(data = sanfran_roads, color = "cornflowerblue", weight = 1, popup = "Roads") %>%
    addPolygons(data = sanfran_buildings, fillOpacity = 1, weight = 1, color="darkorange", fillColor = "orange", popup = "Buildings") %>%
    addCircleMarkers(data = sanfran_trees, popup = "Trees",
    fillColor = "#99CC99", fillOpacity = 1,
    color = "#336600", weight=1, opacity = 1, radius = 1.5) %>%
    addCircleMarkers(data = sanfran_sensors, popup = "Sensors",
    fillColor = "#CC66CC", fillOpacity = 1,
    color = "#9933CC",weight=2, opacity = 1, radius = 5) %>%
    addPolygons(data = sanfran_buffers, color = "#9933CC", weight = 1, opacity = 1, fillOpacity = 0, popup = "Buffers") %>%
    addProviderTiles("CartoDB") %>% 
    addLegend(colors = c("#9933CC", "cornflowerblue", "darkorange", "#336600"), 
    labels = c("PurpleAir Sensors", "Roads", "Buildings", "Trees"))


    ## Plot san fran city


    library(htmlwidgets)
    library(htmltools)


    major_roads <- c("motorway", "motorway_link", "trunk", "primary")

    # group road types to major and minor
    osm_roads_pa <- bayarea_roads %>%
    mutate(highway = ifelse(is.na(highway), "NA", highway)) %>%
    mutate(road_type = ifelse(highway %in% major_roads, "Major", "Minor"),
    road_length = round(st_length(geom),2)) 

    # Define building categories
    house <- c("house", "detached", "semidetached_house", "houses", "farm")
    apartments <- c("residential", "apartments")
    undefined <- c("NA", "yes")

    # Categorize buildings
    buildings <- bayarea_buildings %>% 
    mutate(building = ifelse(is.na(building), "NA", building)) %>%
    mutate(building_type = case_when(
    building %in% undefined ~ "Undefined",
    building %in% house ~ "House",
    building %in% apartments ~ "Apartments",
    TRUE ~ "Other"
    ),
    building_area = round(st_area(geom),2))

    # Remove units from road_length
    # attributes(road_lengths$road_length) = NULL

    # Define colors for road types
    road_colors <- colorFactor(c("cornflowerblue", "lightblue"), domain = c("Major", "Minor"))
    building_colors <- colorFactor(c("orangered", "darkorange", "peachpuff", "papayawhip"), 
    domain = c("Other", "Apartments", "House", "Undefined"))

    m <- leaflet() %>%
    addPolylines(data = osm_roads_pa, color = ~road_colors(road_type), weight = 2,
    label = ~HTML(paste(htmlEscape(road_type), " (", htmlEscape(highway),
    ")<br>Length: ", htmlEscape(road_length), " [m]")),
    popup = "Roads") %>%
    addPolygons(data = buildings, fillOpacity = 1, weight = 1,
    color=~building_colors(building_type), fillColor = ~building_colors(building_type),
    label = ~HTML(paste(htmlEscape(building_type), " (", htmlEscape(building),
    ")<br>Area: ", htmlEscape(building_area), " [m^2]"),
    popup = "Buildings")) %>%
    addCircleMarkers(data = bayarea_trees, popup = "Trees", label = "Tree",
    fillColor = "#99CC99", fillOpacity = 1,
    color = "#336600", weight=1, opacity = 1, radius = 2) %>%
    addCircleMarkers(data = z, popup = "Sensors",
    label = ~paste("Sensor:", htmlEscape(sensor_index)),
    fillColor = "#CC66CC", fillOpacity = 1, color = "#9933CC",
    weight=2, opacity = 1, radius = 5) %>%
    addPolylines(data = purpleairs_buffers, color = "#9933CC", weight = 1,
    opacity = 1, popup = "Buffers") %>%
    addProviderTiles("CartoDB") %>% 
    addLegend(colors = c("#9933CC", "#336600", "cornflowerblue", "lightblue",
    "orangered", "darkorange", "peachpuff", "oldlace"), 
    labels = c("PurpleAir Sensors", "Trees", "Major Roads", "Minor Roads",
    "Other", "Apartments", "House", "Undefined"))
    m
    saveWidget(m, file="san_fran_map.html")
