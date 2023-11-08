# fips_codes: state, county
# Purple airs id, lat, lon
# median household income data from the American Community Survey for each state
# Find number of purple air in each county (by looking at intersections of geometry)
# Interactive map showing number of purpleAir in each census tract
# Interactive map showing number of purpleAir in each country in the world (min 3 purpleAirs)
# Bar plot Number of PurpleAirs by State
# Map of number of PurpleAirs by State

# Load required packages
library(tidycensus) # For accessing US Census data
library(tidyverse) # For data manipulation and visualization
library(units) # For working with physical units
library(rjson) # For working with JSON data
library(httr) # For making HTTP requests
library(sf) # For working with spatial data
library(data.table) # For data manipulation
library(rnaturalearth) # For accessing global map data
library(mapview) # For interactive maps
library(dplyr)
library(stringr)
library(shadowtext)# to create shadow on labels on map
library(leafsync) # combine mapview maps

# set working directory
dir = '/Users/heba/Desktop/Uni/Lim Lab/Purple Air'
setwd(dir)

# Enable caching for faster data retrieval
options(tigris_use_cache = TRUE) 

# Get an sf object for all countries (sf: simple features, an object used to store spatial vector data)
all_countries <- ne_countries(scale = "medium", returnclass = "sf")

# Get a list of unique iso_a3 codes
iso_a3_list <- unique(all_countries$iso_a3)

# Loop over iso_a3 codes to create sf objects for each country
for (iso_a3 in iso_a3_list) {
  # Filter the all_countries data by the iso_a3 code
  country_data <- all_countries %>% filter(iso_a3 == iso_a3)
}

# Print the first few rows of the filtered data
head(country_data)

#sets the API key for accessing the US Census Bureau API
census_api_key("")

# preview fips_codes dataset from the tidycensus library
# fips_codes: state, state_code, state_name, county_code, county
head(tidycensus::fips_codes)

# Get a vector of the unique state codes and select the first 51 (i.e. the 50 states and Washington D.C.)
us <- unique(tidycensus::fips_codes$state)[1:51]

sf <- unique(tidycensus::fips_codes) %>% filter(county == "San Francisco County")

# Store the URL of the API endpoint to request data from for PurpleAir air quality sensors
# location_type=0 outside
# location_type=1 inside
outside <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created&location_type=0"
inside <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created&location_type=1"

# Define the API key used to authenticate the user's request to the PurpleAir API
auth_key  <- ""

# Define the header for the HTTP request to the API, including the API key and Accept content type
header = c(
  'X-API-Key' = auth_key,
  'Accept' = "application/json"
)

# Get Purple Air data using the following steps
# Make the HTTP request to the PurpleAir API using the GET function from the httr library
# Convert the raw content returned by the API into a character string
# Convert the character string into a JSON object
# Extract the "data" element from the JSON object and convert it to a data frame

# get outside purpleair data
result <- GET(outside, add_headers(header))
raw <- rawToChar(result$content)
json <- jsonlite::fromJSON(raw)
pa_outside <- as.data.frame(json$data)
pa_outside$location <- 'outside'
head(pa_outside)

# get inside purpleair data
result <- GET(inside, add_headers(header))
raw <- rawToChar(result$content)
json <- jsonlite::fromJSON(raw)
pa_inside <- as.data.frame(json$data)
pa_inside$location <- 'inside'
head(pa_inside)
# Combine outside and inside purple air data
pa <- rbind(pa_inside, pa_outside)

# Overwrite the column names of the PurpleAir data frame with "ID", "Lat", "Lon", "Location"
colnames(pa) <- c("ID","Date Created", "Lat", "Lon", "Location")

# Remove any rows from the PurpleAir data frame that contain missing values
pa <- pa %>% na.omit()

# Convert the PurpleAir data frame to an sf object with "Lon" and "Lat" as the coordinate columns
dt <- st_as_sf(pa, coords=c("Lon", "Lat"))

# convert epoch timestamp to date
dt$`Date Created` <- as.Date(as.POSIXct(dt$`Date Created`, origin = "1970-01-01"))

# dt: ID (purpleAir ID), Location (inside/outside), geometry (Lat, Lon)
head(dt)

# Use the reduce and map functions from the purrr library to retrieve 
# median household income data from the American Community Survey for each state
census.sf <- reduce(
  map(us, function(x) {
    get_acs(geography = "tract", variables = "B19013_001", 
            state = x, geometry = TRUE)
  }), 
  rbind
)

# # San Francisco
# census.sf <- reduce(
#   map(sf, function(x) {
#     get_acs(geography = "tract", variables = "B19013_001",
#             state = x, geometry = TRUE)
#   }),
#   rbind
# )

# Transform the coordinate reference system (CRS) of the "country_data" sf object to match the CRS of the "census.sf" sf object
country_data<- st_transform(country_data, st_crs(census.sf))

# Assign the coordinate reference system (CRS) of the 'dt' spatial object to be the same as the 'census.sf' object
st_crs(dt) <- st_crs(census.sf)

# # Create a spatial object that contains the intersection of 'dt' with 'census.sf'
# pa.census.sf <- st_intersects(dt, census.sf)

# Add a new column to the 'census.sf' object that contains the number of purple air filters within each polygon
census.sf$pa_count <- lengths(st_intersects(census.sf, dt))
census.sf$inside_count <- lengths(st_intersects(census.sf, dt[dt$Location == "inside",]))
census.sf$outside_count <- lengths(st_intersects(census.sf, dt[dt$Location == "outside",]))

# Calculate the area of each polygon in the 'census.sf' object
census.sf$area <- st_area(census.sf)

# Convert the area to square kilometers
census.sf$area <-  set_units(census.sf$area, km^2)

# Calculate the density of purple air filters per square kilometer for each polygon in the 'census.sf' object
census.sf$density <- as.numeric(census.sf$pa_count/census.sf$area)

# Calculate the density of purple air filters per capita for each polygon in the 'census.sf' object -- estimate: median income
census.sf$density2 <- as.numeric(census.sf$pa_count/census.sf$estimate)

# Filter the 'census.sf' object to keep only polygons with more than 3 purple air filters
pa_city <- filter(census.sf, pa_count>3)


# # SAN FRANCISCO
pa_city <- census.sf %>%
  filter(str_detect(NAME, "San Francisco")) %>%
  filter(pa_count > 0)

# Purple Airs in San Francisco
sf_pa <- st_join(dt,pa_city, join = st_within) %>% select(ID,NAME) %>% filter(NAME != "NA")
sf_pa$ID # 666 features

sf_purpleairs <- sf_pa$ID
# TOTAL PURPLE AIRS
# Create a choropleth map of the purple air filter density for the 'pa_city' object
pa_city %>%
  ggplot(aes(fill = pa_count)) + 
  geom_sf(color = NA) + 
  scale_fill_viridis_c(option = "magma") 

# INSIDE PURPLE AIRS
# Create a choropleth map of the purple air filter density for the 'pa_city' object
pa_city %>%
  ggplot(aes(fill = inside_count)) + 
  geom_sf(color = NA) + 
  scale_fill_viridis_c(option = "magma") 

# OUTSIDE PURPLE AIRS
# Create a choropleth map of the purple air filter density for the 'pa_city' object
pa_city %>%
  ggplot(aes(fill = outside_count)) + 
  geom_sf(color = NA) + 
  scale_fill_viridis_c(option = "magma") 

# Create an interactive map of the 'pa_city' object using the 'mapview' package
# Number of purpleAir in each census tract
map1 = mapview(pa_city, zcol = "pa_count", layer.name = "Total PurpleAirs")
map2 = mapview(pa_city, zcol = "inside_count", layer.name = "Inside PurpleAirs")
map3 = mapview(pa_city, zcol = "outside_count", layer.name = "Outside PurpleAirs")

mapview(ca_pa, zcol = "sensor_id", layer.name = "California PurpleAirs")


sync(map1, map2,map3)

# export -> save as webpage

#############
## USA MAP ##
#############
# Identifying the number of purple air in USA (medium income household) --??
usa <- get_acs(geography = "state", variables = "B19013_001", geometry = TRUE)

# filter us states
usa <- usa %>%
  mutate(State = tidycensus::fips_codes$state[match(NAME, tidycensus::fips_codes$state_name)]) %>%
  filter(State %in% us)

st_crs(dt) <- st_crs(usa)
usa$pa_count <- lengths(st_intersects(usa, dt))
usa$inside_count <- lengths(st_intersects(usa, dt[dt$Location == "inside",]))
usa$outside_count <- lengths(st_intersects(usa, dt[dt$Location == "outside",]))

map_usa = mapview(usa, zcol = "pa_count", layer.name = "Total PurpleAirs")



###################################################
###################################################
###################################################

#identifying the number of purple air in world
# Fix any invalid geometries in the country data
country_data <- st_make_valid(country_data)

# Set the same coordinate reference system for the data frame 'dt' and 'country_data'
st_crs(dt) <- st_crs(country_data)

# Determine which polygons in 'country_data' intersect with the points in 'dt'
pa.country_data<- st_intersects(dt, country_data)

# Count the number of purple-air filters in each polygon and add the results to 'country_data'
country_data$pa_count <- lengths(st_intersects(country_data, dt))

# Calculate the area of each polygon in 'country_data'
country_data$area <- st_area(country_data)

# Convert the area to square kilometers
country_data$area <-  set_units(country_data$area, km^2)

# Calculate the density of purple-air filters per square kilometer in each polygon
country_data$density <- as.numeric(country_data$pa_count/country_data$area)

# Calculate the density of purple-air filters per estimate (median income) in each polygon
# country_data$density2 <- as.numeric(country_data$pa_count/country_data$estimate)

# Only keep polygons where the number of purple-air filters > 3
pa_world1 <- filter(country_data, pa_count>3)

# Create a spatial plot of the filtered polygons, with colors based on the number of purple-air filters
pa_world1 %>%
  ggplot(aes(fill = pa_count)) + 
  geom_sf(color = NA) + 
  scale_fill_viridis_c(option = "magma") 

# create an interactive map of the filtered polygons and their associated purple-air filters
mapview(pa_world1)

###################################################
###################################################
###################################################
# TIME SERIES OF PURPLE AIRS 

# join purple air locations with states based on geometry (lat,long)
dt_with_states <- st_join(dt, usa, join = st_within)

# drop geometry and convert to dataframe
pa_dates_states <- as.data.frame(st_drop_geometry(dt_with_states))

# drop rows with missing values
pa_dates_states <- pa_dates_states %>% na.omit()

# group by date
pa_dates_states <- pa_dates_states %>% 
  select(c("Date Created",Location)) %>%
  count(`Date Created`,Location)

# cumulative sum by date for outdoor
outdoor <- pa_dates_states %>% filter(Location=="outside") %>% select(c(`Date Created`,n))
outdoor <- outdoor %>%
  arrange(`Date Created`) %>% mutate(cumulative_sum = cumsum(n))

# cumulative sum by date for indoor
indoor <- pa_dates_states %>% filter(Location=="inside") %>% select(c(`Date Created`,n))
indoor <- indoor %>%
  arrange(`Date Created`) %>% mutate(cumulative_sum = cumsum(n))


# plot of outdoor units over time (USA)
outdoor_by_time <- ggplot(outdoor, aes(x = `Date Created`, y = cumulative_sum)) +
  geom_line(color = "purple") +
  xlab("Date") +
  ylab("Count") +
  ggtitle("Outdoor Units over Time (USA)") +
  scale_y_continuous(breaks = seq(0, max(outdoor$cumulative_sum), by = 1000)) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year")

outdoor_by_time

# save plot
ggsave("outdoor_by_time.png", outdoor_by_time, width = 10, height = 6, dpi = 300)

# plot of indoor units over time (USA)
indoor_by_time <- ggplot(indoor, aes(x = `Date Created`, y = cumulative_sum)) +
  geom_line(color = "purple") +
  xlab("Date") +
  ylab("Count") +
  ggtitle("Indoor Units over Time (USA)") + 
  scale_y_continuous(breaks = seq(0, max(indoor$cumulative_sum), by = 1000)) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year")

indoor_by_time

# save plot
ggsave("indoor_by_time.png", indoor_by_time, width = 10, height = 6, dpi = 300)


###################################################
###################################################
###################################################
# BAR CHARTS PURPLE AIR BY STATE

# Filter the 'census.sf' object to only keep polygons with purple air filters
pa_city <- filter(census.sf, pa_count>0)

# Separate the comma-separated values in the 'NAME' column of 'pa_city'
# into three separate columns ('Tract', 'Block', and 'State')
split_pa_city <- separate(pa_city, NAME, into = c("Tract", "Block", "State"), sep = ",")

# Display the first six rows of the new 'split_pa_city' data frame
head(split_pa_city)

# Calculate the total number of purple-air filters per state using the new data frame
PA_by_state <- aggregate(cbind(pa_count, inside_count, outside_count) ~ State, split_pa_city, sum)

# Remove leading and trailing whitespaces from state
PA_by_state$State <- str_trim(PA_by_state$State)

# Rename the "State" column using the state abbreviation vector
PA_by_state <- PA_by_state %>%
  mutate(State = tidycensus::fips_codes$state[match(State, tidycensus::fips_codes$state_name)])

# Create a bar plot showing the total number of purple-air filters per state
pa_by_state_plot <- ggplot(PA_by_state, aes(x = State, y = pa_count)) +
  geom_bar(stat = "identity", fill = "purple") +
  xlab("State") +
  ylab("Number of PAs") +
  ggtitle("Total Number of PurpleAirs by State")+
  scale_y_continuous(breaks = seq(0, max(PA_by_state$pa_count), by = 1000)) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

pa_by_state_plot
# save plot
ggsave("pa_by_state_plot.png", pa_by_state_plot, width = 10, height = 6, dpi = 300)

# Create a bar plot showing the total number of purple-air filters per state
inside_pa_by_state_plot <- ggplot(PA_by_state, aes(x = State, y = inside_count)) +
  geom_bar(stat = "identity", fill = "purple") +
  xlab("State") +
  ylab("Number of PAs") +
  ggtitle("Number of Indoor PurpleAirs by State")+
  scale_y_continuous(breaks = seq(0, max(PA_by_state$inside_count), by = 500)) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

inside_pa_by_state_plot
# save plot
ggsave("inside_pa_by_state_plot.png", inside_pa_by_state_plot, width = 10, height = 6, dpi = 300)

# Create a bar plot showing the total number of purple-air filters per state
outside_pa_by_state_plot <- ggplot(PA_by_state, aes(x = State, y = outside_count)) +
  geom_bar(stat = "identity", fill = "purple") +
  xlab("State") +
  ylab("Number of PAs") +
  ggtitle("Number of Outdoor PurpleAirs by State")+
  scale_y_continuous(breaks = seq(0, max(PA_by_state$outside_count), by = 1000)) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

outside_pa_by_state_plot
# save plot
ggsave("outside_pa_by_state_plot.png", outside_pa_by_state_plot, width = 10, height = 6, dpi = 300)


###################################################
###################################################
###################################################
# PURPLE AIR BY STATE MAP (ggplot)

# change state from abbreviation to name
PA_by_state2 <- PA_by_state %>%
  mutate(State = tidycensus::fips_codes$state_name[match(State, tidycensus::fips_codes$state)])

# change state to lowercase
PA_by_state2 <- PA_by_state2 %>%
  mutate(region = tolower(State)) 
# %>% select(region, pa_count)

# sort by pa_count
arrange(PA_by_state2, pa_count)

# create intervals for pa_count
PA_by_state2$pa_intervals <- cut(PA_by_state2$pa_count, breaks = c(0, 20, 50, 100, 200, 1000, 11000),
                                labels = c( "0-20", "21-50", "51-100", "101-200", "201-1000", "1001-11000"))

# join map geometry with purple air data
map_purple_airs = map_data("state") %>%
  left_join(PA_by_state2, by = "region")

# create state labels with long lat for map
state_labels <- map_purple_airs %>%
  group_by(region) %>%
  summarise(
    long = mean(long), 
    lat = mean(lat)
  ) %>%
  mutate(State = tidycensus::fips_codes$state[match(region, tolower(tidycensus::fips_codes$state_name))])

# remove some overlapping states for clarity on map
state_labels_filtered <- state_labels %>%
  filter(!(State %in% c("VT", "DC", "RI", "DE")))

# check counts for states we removed
PA_by_state2 %>%
  mutate(State = tidycensus::fips_codes$state[match(region, tolower(tidycensus::fips_codes$state_name))]) %>%
  filter((State %in% c("VT", "DC", "RI", "DE"))) %>%
  select(State, pa_intervals)

# Rename the "State" column using the state abbreviation vector
PA_by_state2 <- PA_by_state2 %>%
  mutate(State = tidycensus::fips_codes$state[match(State, tidycensus::fips_codes$state_name)])

# Load the 'state' map data and join it with the 'PA_by_state' df
# to visualize the number of PAs by state
pa_by_state_map <- map_purple_airs %>%
  ggplot(aes(x = long, y = lat, group = group, fill = pa_intervals)) +
  geom_polygon() +
  coord_map() +
  scale_fill_manual(values = c("white", "#E8E6FF", "#C5C3FF",  "#7F7DFF",  "#4847cb", "#272771")) +
  labs(title = "Number of Purple Airs by State", fill = "Number of PurpleAirs")+
  geom_shadowtext( data = state_labels_filtered, aes(x = long, y = lat, label = State), inherit.aes = FALSE,  size = 3, fontface = "bold")

# view map
pa_by_state_map

# save plot
ggsave("pa_by_state_map.png", pa_by_state_map, width = 10, height = 6, dpi = 300)

