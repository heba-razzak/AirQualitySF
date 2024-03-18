DataDictionary
================

``` r
library(dplyr) # For data manipulation
library(sf) # For working with spatial data
library(data.table)
```

``` r
setwd('/Users/heba/Desktop/Uni/Lim Lab/OSM')
# read roads file
sanfrancell_roads <- st_read("grid238_roads_osm.shp", quiet = TRUE)
library(explore)
data_dict_md(sanfrancell_roads, 
             title = "Sanfrancell_roads",
             output_file = "data_dict.md",
             output_dir="/Users/heba/Documents/GitHub/lim-lab")
```

## Data Dictionary for `sanfrancell_roads`

# Data Dictionary

## **OSM Roads**

**Number of Rows**: 33701  
*Shapefile*

| variable | type |    na |  %na | unique | description                |
|----------|------|------:|-----:|-------:|----------------------------|
| osm_id   | chr  |     0 |    0 |  33701 | unique identifier from OSM |
| name     | chr  | 22500 | 66.8 |   2190 |                            |
| highway  | chr  |    22 |  0.1 |     25 |                            |
| lanes    | chr  | 28080 | 83.3 |      8 |                            |
| maxspeed | chr  | 29860 | 88.6 |     13 |                            |
| geom     | oth  |     0 |    0 |  33701 |                            |
