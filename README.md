# lim-lab

## Overview

The primary objective of the project is to develop a robust predictive model for PM2.5 concentrations in the Bay Area.

To achieve this goal, the project integrates and analyzes diverse datasets sourced from OpenStreetMap (OSM), PurpleAir, Uber speeds, and weather stations.

## Contents

-   [Data Dictionary](DataDictionary.md): The data dictionary contains a description of each dataset used in the project.

    It provides an overview of each dataset's variables, including their types, the percentage of missing values, unique values, and a description of each variable. It serves as a reference for understanding the structure and contents of the datasets utilized in the project.

-   [Download OpenStreetMap Data](DownloadOSMData.md): Downloading OpenStreetMap (OSM) data for the Bay area, including roads, buildings, and trees.

    It includes steps for defining the bounding box, splitting the map into smaller areas, downloading data for each grid cell, and merging the data into single shapefiles for further analysis.

-   [Download PurpleAir Data](DownloadPurpleAirData.md): Downloading hourly PurpleAir PM2.5 data.

    Download information for all PurpleAir sensors, then filter to area and dates needed. Download historical hourly air quality data for filtered PurpleAir sensors for each month, then combine into one file. Includes bar plot showing number of active PurpleAir sensors for each month.

-   [Combining Uber CSVs](CombiningUberCSVs.md): Filtering and Combining multiple CSV files from Uber.

    Reading individual monthly Uber CSV files, selecting necessary columns, merging data from different files into one for each year, and verifying the correctness of the combined files.

-   [Temperature](Temperature.md): Create hourly weather dataset including temperature, humidity and wind information.

    Obtain weather station information for California using RIEM. Collects weather data for the stations in Bay Area. Processes the retrieved weather data, calculates averages for temperature, relative humidity, wind direction, wind speed, and wind gusts grouped by station and hour.

-   [Data Preprocessing](DataPreprocessing.md): Prepare final dataset. Cleans and combines PurpleAir, Uber, OSM, and weather data.

    Clean PurpleAir data points, ensuring data quality by filtering out inconsistencies. Calculate congestion ratios from uber speeds data. Creates buffer around each purpleair sensor, finds intersections with other datasets and prepares for use in model.

-   [Building Model](model.md): Developing the model for predicting PM2.5 concentrations.

    Trains a random forest model for predicting PM2.5 concentrations and evaluates the model's performance using metrics like Mean Absolute Error (MAE) and R-squared.
