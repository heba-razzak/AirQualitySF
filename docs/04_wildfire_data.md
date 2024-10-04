Wildland Fire Perimeters Data
================

### California Department of Forestry and Fire Protection

[Data
Source](https://www.fire.ca.gov/what-we-do/fire-resource-assessment-program/fire-perimeters)

Load required libraries

``` r
library(dplyr)         # Data manipulation
library(sf)            # Spatial data manipulation
library(leaflet)       # Interactive maps
library(htmlwidgets)   # Creating HTML widgets
library(webshot)       # Convert URL to image
library(DataOverviewR) # Data dictionary and summary
library(units)         # Handling unit objects
library(geosphere)     # Geographic calculations
```

------------------------------------------------------------------------

**Data Dictionary**

#### Wildland Fire Perimeters

`22,261` rows

`22,261` rows with missing values

| Column | Type | Description |
|:--:|:--:|:--:|
| YEAR\_ | integer | Year in which the fire started |
| STATE | character | State in which the fire started |
| AGENCY | character | Direct protection agency responding to fire |
| UNIT_ID | character | ICS code for unit responding to fire |
| FIRE_NAME | character | Name of the fire |
| INC_NUM | character | Number assigned by the Emergency Command Center of the responsible agency for the fire |
| ALARM_DATE | Date | DD/MM/YYYY format, date of fire discovery |
| CONT_DATE | Date | DD/MM/YYYY format, Containment date for the fire |
| CAUSE | integer | Reason fire ignited |
| C_METHOD | integer | Method used to collect perimeter data |
| OBJECTIVE | integer | Tactic for fire response |
| GIS_ACRES | numeric | GIS calculated area, in acres |
| COMMENTS | character | Miscellaneous comments |
| COMPLEX_NA | character | If part of complex, the complex name |
| IRWINID | character | IRWIN stands for Integrated Reporting of Wildland Fire Information, a global unique identifier assigned at the onset of an incident. |
| FIRE_NUM | character | Historical numbering system preceding incident numbers |
| COMPLEX_ID | character | If part of complex, the complex IRWIN ID, however, transitions from incident number previous to 2023 in future update. |
| DECADES | numeric | Decade in which the fire started |
| geometry | sfc_MULTIPOLYGON | Geospatial data |

#### Missing Values

`22,261` rows

`22,261` rows with missing values

|   Column   | NA_Count | NA_Percentage | N_Unique |
|:----------:|:--------:|:-------------:|:--------:|
|   YEAR\_   |    0     |               |   127    |
|   STATE    |    0     |               |    4     |
|   AGENCY   |    53    |      0%       |    11    |
|  UNIT_ID   |    67    |      0%       |   110    |
| FIRE_NAME  |  6,589   |      30%      |  9,109   |
|  INC_NUM   |   975    |      4%       |  7,131   |
| ALARM_DATE |    0     |               |  8,779   |
| CONT_DATE  |    0     |               |  5,292   |
|   CAUSE    |    0     |               |    19    |
|  C_METHOD  |    0     |               |    9     |
| OBJECTIVE  |    0     |               |    3     |
| GIS_ACRES  |    0     |               |  21,960  |
|  COMMENTS  |  19,554  |      88%      |  1,637   |
| COMPLEX_NA |  21,665  |      97%      |   140    |
|  IRWINID   |  19,566  |      88%      |  2,677   |
|  FIRE_NUM  |  5,114   |      23%      |  3,172   |
| COMPLEX_ID |  21,901  |      98%      |    93    |
|  DECADES   |    0     |               |    15    |
|  geometry  |    0     |               |  22,254  |

**View data**

| YEAR\_ | STATE | AGENCY | UNIT_ID | FIRE_NAME | INC_NUM | ALARM_DATE | CONT_DATE | CAUSE | C_METHOD | OBJECTIVE | GIS_ACRES | COMMENTS | COMPLEX_NA | IRWINID | FIRE_NUM | COMPLEX_ID | DECADES | geometry |
|---:|:---|:---|:---|:---|:---|:---|:---|---:|---:|---:|---:|:---|:---|:---|:---|:---|---:|:---|
| 2023 | CA | CDF | SKU | WHITWORTH | 00004808 | 2023-06-17 | 2023-06-17 | 5 | 1 | 1 | 5.72913 | NA | NA | {7985848C-0AC2-4BA4-8F0E-29F778652E61} | NA | NA | 2020 | MULTIPOLYGON (((-13682443 5… |
| 2023 | CA | LRA | BTU | KAISER | 00010225 | 2023-06-02 | 2023-06-02 | 5 | 1 | 1 | 13.60240 | NA | NA | {43EBCC88-B3AC-48EB-8EF5-417FE0939CCF} | NA | NA | 2020 | MULTIPOLYGON (((-13576727 4… |
| 2023 | CA | CDF | AEU | JACKSON | 00017640 | 2023-07-01 | 2023-07-02 | 2 | 1 | 1 | 27.81450 | NA | NA | {B64E1355-BF1D-441A-95D0-BC1FBB93483B} | NA | NA | 2020 | MULTIPOLYGON (((-13459243 4… |

------------------------------------------------------------------------

Link Wildfires and PurpleAir sensors by distance and direction

``` r
filepath <- file.path("data", "processed", "wildfires_purpleair.csv")
if (!file.exists(filepath)) {
  # Add Unique Fire ID
  fire_data <- fire %>%
    mutate(fire_id = row_number())
  fwrite(fire_data %>% st_drop_geometry(), file.path("data", "processed", "wildfires.csv"))
  
  # Filter for California, 2018, 2019 (& 5 days before 2018) 
  fire_sf <- fire_data %>%
    filter(YEAR_ %in% c(2017, 2018, 2019), STATE == "CA") %>% 
    select(fire_id)
  
  # Get distances between purpleAir sensors and fires (within 100km)
  pa_sf <- st_transform(pa_sf, crs = 3310)
  fire_sf <- st_transform(fire_sf, crs = 3310)
  pa_fire_distances <- st_distance(pa_sf, fire_sf, by_element = FALSE)
  distances_df <- as.data.frame(as.table(pa_fire_distances))
  colnames(distances_df) <- c("sensor_pos", "fire_pos", "fire_distance")
  pa_fire_dist <- distances_df %>%
    mutate(
      sensor_index = pa_sf$sensor_index[sensor_pos],
      fire_id = fire_sf$fire_id[fire_pos]
    ) %>%
    select(sensor_index, fire_id, fire_distance) %>%
    mutate(fire_distance = drop_units(fire_distance)) %>% 
    filter(fire_distance <= 100000)
  
  # Get direction (bearing) between PurpleAir sensors and fires
  fire_coords <- st_make_valid(fire_sf) %>%  st_transform(crs = 4326) %>% 
    st_centroid() %>% st_coordinates() %>%  as.data.frame() %>% 
    mutate(fire_id = fire_sf$fire_id) %>% select(fire_id, X, Y) %>%
    rename(fire_x = X, fire_y = Y)
  
  sensor_coords <- st_transform(pa_sf, crs = 4326) %>% 
    st_coordinates() %>% as.data.frame() %>% 
    mutate(sensor_index = pa_sf$sensor_index) %>%
    rename(sensor_x = X, sensor_y = Y)
  
  pa_fire_dist <- pa_fire_dist %>%
    left_join(fire_coords, by = "fire_id") %>%
    left_join(sensor_coords, by = "sensor_index")
  
  wildfires_purpleair <- pa_fire_dist %>%
    mutate(fire_bearing = bearing(cbind(sensor_x, sensor_y), cbind(fire_x, fire_y)),
           fire_direction = round((fire_bearing + 360) %% 360)) %>%
    select(sensor_index, fire_id, fire_distance, fire_direction)
  
  fwrite(wildfires_purpleair, filepath)
}
```

------------------------------------------------------------------------

**Data Dictionary**

#### Wildland Fires, Spatial Calculations (California, 2018-2019)

`65,831` rows

`0` rows with missing values

| Column | Type | Description |
|:--:|:--:|:--:|
| sensor_index | integer | PurpleAir Sensor Index |
| fire_id | integer | Fire Unique Identifier |
| fire_distance | numeric | Distance between fire and PurpleAir (in m) |
| fire_direction | integer | Bearing (Direction) between fire and PurpleAir (in degrees) |

#### Missing Values

`65,831` rows

`0` rows with missing values

|     Column     | NA_Count | NA_Percentage | N_Unique |
|:--------------:|:--------:|:-------------:|:--------:|
|  sensor_index  |    0     |               |   931    |
|    fire_id     |    0     |               |   308    |
| fire_distance  |    0     |               |  65,587  |
| fire_direction |    0     |               |   361    |

**View data**

| sensor_index | fire_id | fire_distance | fire_direction |
|-------------:|--------:|--------------:|---------------:|
|         1208 |    1489 |      98074.53 |              4 |
|         3884 |    1489 |      90699.94 |            342 |
|         4311 |    1489 |      78905.55 |            347 |

------------------------------------------------------------------------
