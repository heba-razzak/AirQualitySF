Combining Uber CSVs
================

## Load required libraries

``` r
library(dplyr) # For data manipulation
library(data.table) # Faster than dataframes (for big files)
```

## Read each uber monthly file, and save it only keeping neccessary columns

``` r
# Get a list of file paths
file_paths <- list.files(file_directory, pattern = "movement-speeds-hourly-san-francisco-.*.csv", full.names = FALSE)

# Read each file and re-save with only required columns
for (file in file_paths) {
  dt <- substr(file,38,50)
  data <- data.table::fread(file)
  data <- data %>% select(utc_timestamp,osm_way_id,speed_mph_mean)
  data <- data[complete.cases(data), ]
  data$osm_way_id <- as.character(data$osm_way_id)
  fwrite(data, paste0("uber-",dt))
}
```

## Read cleaned uber files, and save to 1 file (2018)

``` r
# Get a list of file paths
file_paths <- list.files(file_directory, pattern = "uber-2018.*.csv", full.names = FALSE)

# initialize dfs
dfs <- list()

# Loop through each file and read it into a dataframe
for (file in file_paths) {
  data <- data.table::fread(file)
  dfs[[file]] <- data
}

# Combine all dataframes into one (use column names to bind, fill missing with NA)
uber_data <- rbindlist(dfs, use.names = TRUE, fill = TRUE)

# Save full df to csv
fwrite(uber_data, "uber_2018.csv")
```

## Read cleaned uber files, and save to 1 file (2019)

``` r
# Get a list of file paths
file_paths <- list.files(file_directory, pattern = "uber-2019.*.csv", full.names = FALSE)

# initialize dfs
dfs <- list()

# Loop through each file and read it into a dataframe
for (file in file_paths) {
  data <- data.table::fread(file)
  dfs[[file]] <- data
}

# Combine all dataframes into one (use column names to bind, fill missing with NA)
uber_data <- rbindlist(dfs, use.names = TRUE, fill = TRUE)

# Save full df to csv
fwrite(uber_data, "uber_2019.csv")
```

## Check that 2018 and 2019 files contain correct number of rows

``` r
# Get a list of file paths
file_paths <- list.files(file_directory, pattern = "uber-.*.csv", full.names = FALSE)

# initialize number of rows
total_rows <- 0

# Loop through each file and read it into a dataframe
for (file in file_paths) {
   # read file
  data <- data.table::fread(file)

  # Count the number of rows in the data
  num_rows <- nrow(data)

  # Add the number of rows to the total row count
  total_rows <- total_rows + num_rows
}

cat("Total Rows all monthly files: ", format(total_rows, big.mark = ",", scientific = F), "\n")
```

    ## Total Rows all monthly files:  631,636,425

``` r
# print number of rows for 2018-2019 file
file = "uber_2018.csv"
data <- data.table::fread(file)
num_rows2018 <- nrow(data)

file = "uber_2019.csv"
data <- data.table::fread(file)
num_rows2019 <- nrow(data)

cat("\n Total Rows 2018+2019 files: ", format(num_rows2018 + num_rows2019, big.mark = ",", scientific = F),"\n")
```
    ##  Total Rows 2018+2019 files:  631,636,425
