library(dplyr)
library(lubridate)

# # install AirSensor Package from github
# install.packages('knitr')
# install.packages('rmarkdown')
# devtools::install_github("MazamaScience/AirSensor")
library(AirSensor)


get.sensor.list.bbox <- function(read.key, nwlng, nwlat, selng, selat, location.type="outside") {
  if (is.null(location.type)) {
    url = sprintf("https://api.purpleair.com/v1/sensors?fields=location_type%%2Clatitude%%2Clongitude%%2Caltitude&nwlng=%.5f&nwlat=%.5f&selng=%.5f&selat=%.5f", nwlng, nwlat, selng, selat)
  } else {
    if (location.type == "outside") {
      loc.num = 0
    } else {
      loc.num = 1
    }
    url = sprintf("https://api.purpleair.com/v1/sensors?fields=location_type%%2Clatitude%%2Clongitude%%2Caltitude&location_type=%s&nwlng=%.5f&nwlat=%.5f&selng=%.5f&selat=%.5f", loc.num, nwlng, nwlat, selng, selat)
  }
  response = httr::GET(url, httr::add_headers(`X-API-Key` = api_key))
  print(response)
  response
}


sensor.list.response.to.df <- function(response) {
  data.content = httr::content(response)$data
  stations <- tibble::tibble(sensor_index = numeric(),
                             location_type = numeric(), latitude = numeric(),
                             longitude = numeric(), altitude = numeric())
  
  for (i in seq_along(data.content)) {
    stations[i, ] <- data.content[[i]]
  }
  stations
}

# San Francisco bounding box
#
# north west: 37.814123624, -122.522884398
# 
# south east: 37.708280216, -122.353282952
nwlng=-122.522884398
nwlat=37.814123624
selng=-122.353282952
selat=37.708280216

r = get.sensor.list.bbox(api_key, nwlng, nwlat, selng, selat)
df = sensor.list.response.to.df(r)

sensor_ids = df$sensor_index

# Treasure Island & Alcatraz (includes NW corner of SF)
#
# north west: 37.842039823, -122.433722402
# 
# south east: 37.782936609, -122.353041556
nwlng=-122.433722402
nwlat=37.842039823
selng=-122.353041556
selat=37.805293405


r = get.sensor.list.bbox(api_key, nwlng, nwlat, selng, selat)

df = sensor.list.response.to.df(r)

sensor_ids = unique(c(sensor_ids,df$sensor_index))




dir = '/Users/heba/Desktop/Uni/Lim Lab'
setwd(dir)
# install.packages("mapview")

api_key = ""

purple_air = getPurpleairApiHistory(
    sensorIndex=sensor_ids,
    apiReadKey=api_key,
    startTimeStamp="2018-01-01 00:00:00",
    endTimeStamp="2018-01-31 23:59:59",
    average="60",
    fields=c("pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")
)
write.csv(purple_air, file = "/Users/heba/Desktop/Uni/Lim Lab/purple_air_sf.csv", row.names = FALSE)

split_timestamps <- function(start_time, end_time, time_interval) {
  timestamps <- seq(from=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"), 
                    to=as.POSIXct(end_time, format="%Y-%m-%d %H:%M:%S"), 
                    by="day")
  return (data.frame(start_time=timestamps[-length(timestamps)], 
                     end_time=timestamps[-1]))
}

# Define a function to get PurpleAir data for a specified time range and time interval
getPurpleAirData <- function(api_key, sensor_indices, start_time, end_time, time_interval, fields, average) {
  # Split the start and end times into time intervals
  time_intervals <- split_timestamps(start_time, end_time, time_interval)
  
  # Initialize an empty list to store the data
  data_list <- list()
  
  # Loop over the time intervals and get PurpleAir data
  for (i in 1:(length(time_intervals)-1)) {
    # Get the start and end timestamps for this iteration
    start_timestamp <- time_intervals[i]
    end_timestamp <- time_intervals[i+1]
    
    # Get the PurpleAir data for this iteration
    purple_air <- getPurpleairApiHistory(
      sensorIndex = sensor_indices,
      apiReadKey = api_key,
      startTimeStamp = start_timestamp,
      endTimeStamp = end_timestamp,
      average = average,
      fields = fields
    )
    
    # Append the data to the list
    data_list[[i]] <- purple_air
  }
  
  # Combine the list into a single data frame
  data_df <- do.call(rbind, data_list)
  
  # Return the data frame
  return(data_df)
}


time_interval <- days(10)
sensorIndex=c("131079")
api_key = ""
start_time="2022-12-01 00:00:00"
end_time="2022-12-30 23:59:59"
average="10"
fields=c("pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")


getPurpleAirData(api_key, sensor_indices, start_time, end_time, time_interval, fields, average)


split_timestamps <- function(start_timestamp, end_timestamp) {
  # Convert start and end timestamps to POSIXct format
  start_time <- as.POSIXct(start_timestamp, format = "%Y-%m-%d %H:%M:%S")
  end_time <- as.POSIXct(end_timestamp, format = "%Y-%m-%d %H:%M:%S")
  
  # Compute the number of hours between start and end time
  num_hours <- difftime(end_time, start_time, units = "hours")
  
  # Create a sequence of hourly timestamps
  hourly_timestamps <- seq(from = start_time, to = end_time, by = "hour")
  
  # Return the hourly timestamps as a list
  return(list(hourly_timestamps))
}

start_time="2022-12-26 00:00:00"
end_time="2022-12-26 23:59:59"

hourly_timestamps <- split_timestamps(start_time, end_time)[[1]]

# Initialize a list to store the data
purple_air_list <- list()

# Loop over the hourly timestamps and get PurpleAir data
for (i in 1:(length(hourly_timestamps)-1)) {
  # Get the start and end timestamps for this iteration
  start_timestamp <- hourly_timestamps[i]
  end_timestamp <- hourly_timestamps[i+1]
  
  # Get the PurpleAir data for this iteration
  purple_air <- getPurpleairApiHistory(
    sensorIndex = sensor_ids,
    apiReadKey = api_key,
    startTimeStamp = start_timestamp,
    endTimeStamp = end_timestamp,
    average = "10",
    fields = c("pm2.5_atm", "pm2.5_atm_a", "pm2.5_atm_b")
  )
  
  # Append the data to the list
  purple_air_list[[i]] <- purple_air
}

# Combine the list into a single data frame
purple_air_df <- do.call(rbind, purple_air_list)



