# fips_codes: state, county
# Purple airs id, lat, lon
# median household income data from the American Community Survey for each state
# Find number of purple air in each county (by looking at intersections of geometry)
# Interactive map showing number of purpleAir in each census tract
# Interactive map showing number of purpleAir in each country in the world (min 3 purpleAirs)
# Bar plot Number of PurpleAirs by State
# Map of number of PurpleAirs by State

# Load required packages
library(rjson) # For working with JSON data
library(httr) # For making HTTP requests
library(sf) # For working with spatial data
library(dplyr)
library(tidycensus) # For accessing US Census data
library(tidyverse) # For data manipulation and visualization
library(lubridate) # For working with dates
library(ggplot2) # For visualizing data

# set working directory
dir = '/Users/heba/Desktop/Uni/Lim Lab/Purple Air'
setwd(dir)

# Enable caching for faster data retrieval
options(tigris_use_cache = TRUE) 

# sets the API key for accessing the US Census Bureau API
census_api_key("")

# Store the URL of the API endpoint to request data from for PurpleAir air quality sensors
# location_type=0 outside
# location_type=1 inside
# outside <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created&location_type=0"
# inside <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created&location_type=1"
all <- "https://api.purpleair.com/v1/sensors?fields=latitude%2C%20longitude%2C%20date_created%2C%20last_seen"

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

# # get outside purpleair data
# result <- GET(outside, add_headers(header))
# raw <- rawToChar(result$content)
# json <- jsonlite::fromJSON(raw)
# pa_outside <- as.data.frame(json$data)
# pa_outside$location <- 'outside'
# head(pa_outside)
# 
# # get inside purpleair data
# result <- GET(inside, add_headers(header))
# raw <- rawToChar(result$content)
# json <- jsonlite::fromJSON(raw)
# pa_inside <- as.data.frame(json$data)
# pa_inside$location <- 'inside'
# head(pa_inside)
# # Combine outside and inside purple air data
# pa <- rbind(pa_inside, pa_outside)

# get all purpleair data
result <- GET(all, add_headers(header))
raw <- rawToChar(result$content)
json <- jsonlite::fromJSON(raw)
pa <- as.data.frame(json$data)

# Rename the columns of the PurpleAir data frame
colnames(pa) <- c("sensor_id","date_created", "last_seen", "lat", "lon")

# convert epoch timestamp to date
pa$date_created <- as.Date(as.POSIXct(pa$date_created, origin = "1970-01-01"))
pa$last_seen <- as.Date(as.POSIXct(pa$last_seen, origin = "1970-01-01"))

# only keep purple airs created before June 2019
pa <- pa %>% filter(date_created <= "2019-06-01")
pa <- pa %>% filter(last_seen >= "2023-06-01")

# Remove any rows from the PurpleAir data frame that contain missing values
pa <- pa %>% na.omit() 

# view pa
head(pa)

# count number of sensors
length(unique(pa$sensor_id)) # 3326

# Convert the PurpleAir data frame to an sf object with "Lon" and "Lat" as the coordinate columns
dt <- st_as_sf(pa, coords=c("lon", "lat"))

# Retrieve median household income data from the American Community Survey for each state
# California
census.sf <- get_acs(geography = "tract", variables = "B19013_001",
                     state = 'CA', geometry = TRUE)

# Assign the coordinate reference system (CRS) of the 'dt' spatial object to be the same as the 'census.sf' object
st_crs(dt) <- st_crs(census.sf)

# SAN FRANCISCO
pa_city <- census.sf %>%
  filter(str_detect(NAME, "San Francisco")) 

# Purple Airs in San Francisco (left = FALSE: inner join)
sf_pa <- st_join(dt,pa_city, join = st_intersects, left = FALSE) 

# list of purple air ids in san francisco
sf_purpleairs <- unique(sf_pa$sensor_id)

# count number of sensors in san francisco
length(sf_purpleairs) # 59

library(mapview) # For interactive maps
mapview(sf_pa, zcol = "sensor_id", layer.name = "California PurpleAirs")

# Inputs for purple air function
apiReadKey = "2C4E0A86-014A-11ED-8561-42010A800005"
fields=c("pm1.0_atm, pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")
average="60"

# Date range
start_date <- as.Date("2022-04-01")
end_date <- as.Date("2023-06-30")
current_date <- start_date

# Iterate over each 1 month period
while (current_date <= end_date) {
  
  # Calculate next date
  next_date <- current_date + months(1) - days(1)
  
  # Ensure we don't go beyond the end date
  if (next_date > end_date) {
    next_date <- end_date
  }
  
  # Print the dates we're processing
  print(paste("Processing:", current_date, "-", next_date))
  start_time <- Sys.time()
  
  # Get the data
  purple_air <- getPurpleairApiHistory(
    sensorIndex=sf_purpleairs,
    # sensorIndex=c("2031", "2910",  "3998",  "5448",  "5478",  "5776", "16903", "16927"),
    apiReadKey=apiReadKey,
    startTimeStamp=format(current_date, "%Y-%m-%d %H:%M:%S"),
    endTimeStamp=format(next_date, "%Y-%m-%d %H:%M:%S"),
    average=average,
    fields=fields
  )
  
  # Save to CSV file
  write.csv(purple_air, file = paste0("purple_air_sf_", current_date, "_", next_date, ".csv"), row.names = FALSE)
  
  # Print time it took
  end_time <- Sys.time()
  time_difference <- end_time - start_time
  print(paste("Processing time:", current_date, "-", next_date))
  print(time_difference)
  
  # Update the current date
  current_date <- next_date + days(1)
}

#########################################################
# Analyze SF purple air data from June 2019 - June 2023 #
#########################################################

# List all files in the current directory
files <- list.files(path = ".")

# Get the files that start with "purple_air_sf_" and end with ".csv"
files <- files[grepl("^purple_air_sf_.*\\.csv$", files)]

# Read all these CSV files into data frames
data_list <- lapply(files, read.csv)

# Bind all data frames into a single data frame
df <- do.call(rbind, data_list)

# select relevant columns
df <- df[, c("sensor_id", "time_stamp", "pm1.0_atm", "pm2.5_atm")]

# convert time_stamp to Date or POSIXct
df$time_stamp <- as.POSIXct(df$time_stamp, origin="1970-01-01", tz="UTC")

# ratio = pm1/pm2.5
df$ratio <- df$pm1.0_atm / df$pm2.5_atm

# add year, month, day, day of week, hour
df$year <- year(df$time_stamp)
df$month <- month(df$time_stamp)
df$month_label <- lubridate::month(df$time_stamp, label = TRUE, abbr = TRUE)
df$day <- day(df$time_stamp)
df$dow <- lubridate::wday(df$time_stamp, label = TRUE, abbr = TRUE)
df$hour <- hour(df$time_stamp)

# preview df
glimpse(df)
colnames(df)

# number of sensors
length(unique(df$sensor_id))

#########
# PLOTS #
df2 <- na.omit(df)

d <- density(x) # returns the density data
plot(d)

library(ggplot2)

# Density plots
density_plots <- ggplot(df, aes(x = ratio, fill = as.factor(year))) +
  geom_density(alpha = 0.5) +
  facet_wrap(~ year, ncol = 1) +
  labs(title = "Density Plots by Year", x = "Ratio", y = "Density") +
  theme_minimal()

# Box plots
box_plots <- ggplot(df, aes(x = as.factor(year), y = ratio, fill = as.factor(year))) +
  geom_boxplot() +
  labs(title = "Box Plots by Year", x = "Year", y = "Ratio") +
  theme_minimal()

# Identify outliers
outliers <- df2 %>%
  group_by(year) %>%
  mutate(outlier = ifelse(ratio < quantile(ratio, 0.25) - 1.5 * IQR(ratio) |
                            ratio > quantile(ratio, 0.75) + 1.5 * IQR(ratio), "Outlier", "Not Outlier"))

# Dates of outliers
outlier_dates <- outliers %>% ungroup(year) %>%
  filter(outlier == "Outlier") %>%
  select(year, time_stamp, ratio) %>% mutate(date = format(time_stamp, "%Y-%m-%d")) %>% 
  group_by(year, date) %>% summarise(mean_ratio = mean(ratio), count=n())

# plot outlier dates
hist(outlier_dates)
ggplot(outlier_dates, aes(x = time_stamp, fill = as.factor(year))) +
  geom_density(alpha = 0.5) +
  facet_wrap(~ year, ncol = 1) +
  labs(title = "Density Plots by Year", x = "outlier", y = "Density") +
  theme_minimal()

# View the density plots
density_plots

# View the box plots
box_plots

###################################################
# AVG RATIO OVER TIME (FULL DATA FACETED BY YEAR) #
###################################################

# average ratio for all sensors
avg_ratio <- aggregate(df$ratio, by=list(df$time_stamp), FUN=mean, na.rm=TRUE)
names(avg_ratio) <- c("time_stamp", "avg_ratio")

# add year column
avg_ratio$year <- year(avg_ratio$time_stamp)

# timestamp without year
avg_ratio$time_stamp2 <- format(avg_ratio$time_stamp, "%m-%d %H:%M:%S")

# Line plot of average ratio for each year
p <- ggplot(avg_ratio, aes(x = as.POSIXct(time_stamp2, format = "%m-%d %H:%M:%S"), y = avg_ratio)) +
  geom_line() +
  facet_grid(year ~ ., scales = "free_x") +
  scale_x_datetime(date_breaks = "1 month", date_labels = "%b") +
  labs(title = "PM1/PM2.5 over time", x = "Time", y = "Average Ratio") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(filename = "purpleairratio.png", plot = p, width = 20, height = 8, dpi = 300)

###################################################

###################
# DATA PROCESSING # 
###################

# Aggregate by month and sensor_id
df_avg_sensor <- df %>%
  group_by(sensor_id, year, month, month_label) %>%
  summarise(avg_ratio = mean(ratio, na.rm = TRUE))

# convert sensor_id to factor
df_avg_sensor$sensor_id <- as.factor(df_avg_sensor$sensor_id)

# Convert month_label to factor with levels ordered as actual months
df_avg_sensor$month_label <- factor(df_avg_sensor$month_label, levels = month.abb)

# Calculate change in ratio
df_avg_sensor <- df_avg_sensor %>%
  arrange(sensor_id, year, month) %>%
  group_by(sensor_id) %>%
  mutate(change = avg_ratio - lag(avg_ratio))

# Aggregate by month and year for all sensors
df_avg_all <- df_avg_sensor %>%
  group_by(year, month, month_label) %>%
  summarise(avg_ratio = mean(avg_ratio, na.rm = TRUE),
            avg_change = mean(change, na.rm = TRUE))

#########
# PLOTS # 
#########

# PLOT AVERAGE RATIO BY MONTH (FACETED YEARS)

# Line plot showing all sensors
ggplot(df_avg_sensor, aes(x = month_label, y = avg_ratio, color = sensor_id)) +
  geom_line(aes(group = sensor_id)) +
  facet_grid(year ~ ., scales = "free_x") +
  labs(title = "Average Ratio by Month", x = "Month", y = "Average Ratio") +
  theme_minimal()

# Line plot showing average of all sensors
ggplot(df_avg_all, aes(x = month_label, y = avg_ratio, color = as.factor(year), group = year)) +
  geom_line() +
  facet_grid(year ~ ., scales = "free_x") +
  labs(title = "Average Ratio by Month Across Sensors", x = "Month", y = "Average Ratio") +
  scale_color_discrete(name = "Year") +
  theme_minimal()

# PLOT CHANGES IN RATIO BY MONTH (FACETED YEARS)

# Plot month/year
ggplot(df_avg_all, aes(x = month_label, y = avg_change, group = year)) +
  geom_line(aes(color = as.factor(year))) +
  geom_hline(yintercept = 0, linetype = "solid", color = "black", size = 0.5) +
  labs(title = "Average Change in Ratio by Month", x = "Month", y = "Change in Average Ratio") +
  scale_color_discrete(name = "Year") +
  theme_minimal()










#########
# PLOTS # 
#########

# PLOT AVERAGE RATIO BY MONTH (FACETED YEARS)

# Aggregate by month and sensor_id
df_avg <- df %>%
  group_by(sensor_id, year, month, month_label) %>%
  summarise(avg_ratio = mean(ratio, na.rm = TRUE))

# convert sensor_id to factor
df_avg$sensor_id <- as.factor(df_avg$sensor_id)

# Convert month_label to factor with levels ordered as actual months
df_avg$month_label <- factor(df_avg$month_label, levels = month.abb)

# Line plot showing all sensors
# AVERAGE MONTHLY RATIO BY MONTH & YEAR (FOR EACH SENSOR)
ggplot(df_avg, aes(x = month_label, y = avg_ratio, color = sensor_id)) +
  geom_line(aes(group = sensor_id)) +
  facet_grid(year ~ ., scales = "free_x") +
  labs(title = "Average Ratio by Month", x = "Month", y = "Average Ratio") +
  theme_minimal()

# Aggregate by month and year for all sensors
df_avg_all <- df_avg %>%
  group_by(year, month, month_label) %>%
  summarise(avg_ratio = mean(avg_ratio, na.rm = TRUE))

# Line plot showing average of all sensors
# AVERAGE MONTHLY RATIO BY MONTH & YEAR (AVG OF SENSORS)
ggplot(df_avg_all, aes(x = month_label, y = avg_ratio, color = as.factor(year), group = year)) +
  geom_line() +
  facet_grid(year ~ ., scales = "free_x") +
  labs(title = "Average Ratio by Month Across Sensors", x = "Month", y = "Average Ratio") +
  scale_color_discrete(name = "Year") +
  theme_minimal()

# PLOT CHANGES IN RATIO BY MONTH (FACETED YEARS)

# Calculate change in ratio
df_avg <- df_avg %>%
  arrange(sensor_id, year, month) %>%
  group_by(sensor_id) %>%
  mutate(change = avg_ratio - lag(avg_ratio))

# Calculate average change across all sensors
df_avg_all <- df_avg %>%
  group_by(year, month_label) %>%   # Group by year and month
  summarise(avg_change = mean(change, na.rm = TRUE)) # Calculate average change

# Convert month_label to factor with levels ordered as actual months
df_avg_all$year <- factor(df_avg_all$year)

# Plot month/year
ggplot(df_avg_all, aes(x = month_label, y = avg_change, group = year)) +
  geom_line(aes(color = as.factor(year))) +
  geom_hline(yintercept = 0, linetype = "solid", color = "black", size = 0.5) +
  labs(title = "Average Change in Ratio by Month", x = "Month", y = "Change in Average Ratio") +
  scale_color_discrete(name = "Year") +
  theme_minimal()

# Line plot
ggplot(df_avg_all, aes(x = month_label, y = avg_change, group=year)) +
  geom_line(aes(color =year)) +
  facet_grid(year ~ ., scales = "free_x") +
  geom_hline(yintercept = 0, linetype = "solid", color = "black", size = 0.5) +
  labs(title = "Average Ratio by Month", x = "Month", y = "Average Ratio") +
  theme_minimal()







# Randomly select 10 sensors
set.seed(123) # for reproducibility
selected_sensors <- sample(unique(df_avg$sensor_id), 10)

# Filter data to only include the 10 selected sensors
df_avg_selected <- df_avg %>% 
  filter(sensor_id %in% selected_sensors)


df_avg_selected$sensor_id <- as.factor(df_avg_selected$sensor_id)

# Line plot
ggplot(df_avg_selected, aes(x = month, y = avg_ratio, color = sensor_id)) +
  geom_line() +
  labs(title = "Average Ratio by Month", x = "Month", y = "Average Ratio") +
  theme_minimal()



# line graph showing ratio by month
ggplot(df, aes(x = month, y = ratio, color = sensor_id)) +
  geom_line() +
  labs(title = "Concentration of particles over time", x = "Time", y = "Concentration") +
  theme_minimal()

# line graph showing ratio
ggplot(df, aes(x = time_stamp, y = ratio, color = sensor_id)) +
  geom_line() +
  labs(title = "Concentration of particles over time", x = "Time", y = "Concentration") +
  theme_minimal()

# scatterplot showing ratio
ggplot(df, aes(x = time_stamp, y = ratio, color = sensor_id)) +
  geom_point() +
  labs(title = "Concentration of particles over time", x = "Time", y = "Concentration") +
  theme_minimal()

# average ratio for all sensors
avg_ratio <- aggregate(df$ratio, by=list(df$time_stamp), FUN=mean, na.rm=TRUE)
names(avg_ratio) <- c("time_stamp", "avg_ratio")

# add year column
avg_ratio$year <- year(avg_ratio$time_stamp)

# timestamp without year
avg_ratio$time_stamp2 <- format(avg_ratio$time_stamp, "%m-%d %H:%M:%S")

# Line plot of average ratio for each year
p <- ggplot(avg_ratio, aes(x = as.POSIXct(time_stamp2, format = "%m-%d %H:%M:%S"), y = avg_ratio)) +
  geom_line() +
  facet_grid(year ~ ., scales = "free_x") +
  scale_x_datetime(date_breaks = "1 month", date_labels = "%b") +
  labs(title = "PM1/PM2.5 over time", x = "Time", y = "Average Ratio") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(filename = "purpleairratio.png", plot = p, width = 20, height = 8, dpi = 300)


# line plot of average ratio over time
ggplot(avg_ratio, aes(x = time_stamp, y = avg_ratio)) +
  geom_line() +
  labs(title = "Average ratio over time", x = "Timestamp", y = "Average Ratio") +
  theme_minimal()

# smoothes line plot
ggplot(avg_ratio, aes(x = time_stamp, y = avg_ratio)) +
  geom_line() +
  geom_smooth(method = "loess", se = FALSE, color = "red") +
  labs(title = "Average ratio over time", x = "Timestamp", y = "Average Ratio") +
  theme_minimal()

# transform data from wide format to long format
df_long <- tidyr::gather(df, key = "particle", value = "concentration", -sensor_id, -time_stamp)



# line graph showing pm1.0_atm and pm2.5_atm over time for each sensor
ggplot(df_long, aes(x = time_stamp, y = concentration, color = sensor_id)) +
  geom_line() +
  facet_wrap(~ particle, scales = "free_y") +
  labs(title = "Concentration of particles over time", x = "Time", y = "Concentration") +
  theme_minimal()

# scatterplot showing pm1.0_atm and pm2.5_atm over time for each sensor
ggplot(test_df, aes(x = time_stamp, y = concentration, color = sensor_id)) +
  geom_point() +
  facet_wrap(~ particle, scales = "free_y") +
  labs(title = "Concentration of particles over time", x = "Time", y = "Concentration") +
  theme_minimal()

# filter data for 1 sensor
test_df <- df_long %>% filter(sensor_id == "2031")
test_df2 <- df %>% filter(sensor_id == "2031")

# pm1/pm2.5 ratio changes over time - pm1 smaller particles, pm2.5 larger particles
# see if theres patterns
# average and each sensor plots
