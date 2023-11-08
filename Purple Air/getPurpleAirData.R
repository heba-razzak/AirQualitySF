########################
#     Description      #
########################

# getPurpleAirData
# Given a time interval, uses getPurpleairApiHistory function to download 
# PurpleAir data, by splitting the total duration into multiple time intervals

########################
#      IMPORTANT       #
########################

# First getPurpleairApiHistory function MUST be loaded
# This can be done by running the getPurpleairApiHistory.R

# To check if getPurpleairApiHistory has been loaded
# running the line below should return TRUE
exists("getPurpleairApiHistory")

########################
#         Usage        #
########################

# getPurpleAirData(api_key,
#                  sensor_indices, 
#                  start_time, 
#                  end_time, 
#                  numDaysInterval, 
#                  fields, 
#                  average)

########################
#      Arguments       #
########################

# sensorIndex       The sensor index found in the url (?select=sensor_index) of a selected sensor in the purpleair maps purpleair map.
# apiReadKey        PurpleAir API read key with access to historical data. See PurpleAir Community website for more information.
# startTimeStamp    The beginning date in the format "YYYY-MM-DD HH:mm:ss".
# endTimeStamp      The end date in the format "YYYY-MM-DD" HH:mm:ss.
# average           The desired average in minutes, one of the following: "0" (real-time), "10", "30", "60", "360" (6 hour), "1440" (1 day).
# fields            The "Fields" parameter specifies which 'sensor data fields' to include in the response.
# numDaysInterval   The interval which the total duration will be split into, ex: 10 day intervals

########################
#       Example        #
########################

# numDaysInterval <- 10
# sensorIndex=c("131079")
# api_key = "2C4E0A86-014A-11ED-8561-42010A800005"
# start_time="2022-12-01 00:00:00"
# end_time="2022-12-21 00:00:00"
# average="1440"
# fields=c("pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")
# 
# getPurpleAirData(api_key, sensor_indices, start_time, end_time, numDaysInterval, fields, average)

########################
#      Function        #
########################

# split_timestamps splits the time period between start_time and end_time according to the numDaysInterval
split_timestamps <- function(start_time, end_time, numDaysInterval) {
  
  # timestamps is a sequence from start_time to end_time in increments of numDaysInterval
  timestamps <- seq(from=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"), 
                    to=as.POSIXct(end_time, format="%Y-%m-%d %H:%M:%S"), 
                    by=numDaysInterval*24*60*60)
  
  # if last timestamp is less than end time, add end time to timestamps
  if (tail(timestamps, 1) < as.POSIXct(end_time, format = "%Y-%m-%d %H:%M:%S")) {
    timestamps <- c(timestamps, as.POSIXct(end_time, format = "%Y-%m-%d %H:%M:%S"))
  }
  
  # return dataframe with 2 columns, start_time and end_time, and each row duration is <= numDaysInterval
  return (data.frame(start_time=timestamps[-length(timestamps)], 
                     end_time=timestamps[-1]))
}

# Define a function to get PurpleAir data for a specified time range and time interval
getPurpleAirData <- function(api_key, sensor_indices, start_time, end_time, numDaysInterval, fields, average) {
  # Split the start and end times into time intervals
  time_intervals <- split_timestamps(start_time, end_time, numDaysInterval)
  
  # Initialize an empty list to store the data
  data_list <- list()
  
  # Loop over the time intervals and get PurpleAir data
  for (i in 1:(nrow(time_intervals))) {

    # Get the start and end timestamps for this iteration
    start_timestamp <- time_intervals[i,1]
    end_timestamp <- time_intervals[i,2]
    
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
  
  # colNames of fields
  colNames <- strsplit(fields, ", ")[[1]]
  
  # drop rows where these columns are empty
  data_df <- data_df[complete.cases(data_df[, colNames]), ]
  
  # reset index
  data_df <- data.frame(data_df, row.names = NULL)
  
  # Return the data frame
  return(data_df)
}


# # testing
# numDaysInterval <- 10
# sensor_indices=c("131079")
# api_key = "2C4E0A86-014A-11ED-8561-42010A800005"
# start_time="2022-12-01 00:00:00"
# end_time="2022-12-25 23:59:59"
# average="1440"
# fields=c("pm2.5_atm, pm2.5_atm_a, pm2.5_atm_b")
# 
# pa <- getPurpleAirData(api_key, sensor_indices, start_time, end_time, numDaysInterval, fields, average)
# 
# # gets 1 extra day before start and doesnt include end date ?? due to changing to UTC time zone?