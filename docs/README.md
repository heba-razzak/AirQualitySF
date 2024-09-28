# AirQualitySF

## Overview

The primary objective of the project is to develop a robust predictive model for PM2.5 concentrations in the Bay Area.

To achieve this goal, the project integrates and analyzes diverse datasets sourced from OpenStreetMap (OSM), PurpleAir, Uber speeds, and weather stations.

## Contents

-   [Data Dictionary](DataDictionary.md): The data dictionary contains a description of each dataset used in the project.

    It provides an overview of each dataset's variables, including their types, the percentage of missing values, unique values, and a description of each variable. It serves as a reference for understanding the structure and contents of the datasets utilized in the project.
    
-   [Download PurpleAir Data](DownloadPurpleAirData.md): Downloading hourly PurpleAir PM2.5 data.

    Download information for all PurpleAir sensors, then filter to area and dates needed. Download historical hourly air quality data for filtered PurpleAir sensors for each month, then combine into one file. 
    Visualizations: Map of PurpleAir Sensors in Bay Area, Map of PurpleAir Sensors in Bay Area in 2018-2019, Bar plot showing number of active PurpleAir sensors for each month.
    
-   [Preprocessing PurpleAir](PreprocessingPurpleAir.md): Clean PurpleAir data points

    Clean PurpleAir data points, ensuring data quality by dealing with outliers and inconsistencies. Visualization of outliers.

-   [Download OpenStreetMap Data](DownloadOSMData.md): Downloading OpenStreetMap (OSM) data for the Bay area, including roads, buildings, and trees.

    Creates buffer around each purpleair sensor, downloads OSM data surrounding each PurpleAir sensor, and merges the data into single shapefiles for further analysis.

-   [Download Weather Data](DownloadWeatherData.md): Create hourly weather dataset including temperature, humidity and wind information.

    Obtain weather station information for California using RIEM. Collects weather data for the stations in Bay Area. Processes the retrieved weather data, calculates averages for temperature, relative humidity, wind direction, wind speed, and wind gusts grouped by station and hour.

-   [Preprocessing Weather](PreprocessingWeather.md): Link PurpleAir sensors with nearest weather station

    Link PurpleAir sensors with nearest weather station and visualize on map.

-   [Preprocessing Uber](PreprocessingUber.md): Calculate Free Flow Speeds and Congestion Ratio

    Reading individual monthly Uber CSV files, select necessary columns, filter uber data near PurpleAir sensors, calculate Free Flow Speeds and Congestion Ratio, save combined traffic file. Visualization of free flow speeds and traffic congestion.

-   [Feature Engineering](FeatureEngineering.md): Creating new features and building final dataset

    Calculate building areas, road lengths, and number of trees surrounding PurpleAir sensors. Create new columns to represent temporal aspects such as day, hour, and weekend. Create feature for lat and lon. Integrating cleaned and processed data from various sources to create the final dataset.

-   [Model Building](ModelBuilding.md): Developing the model for predicting PM2.5 concentrations.

    Trains a random forest model for predicting PM2.5 concentrations and evaluates the model's performance using metrics like Mean Absolute Error (MAE) and R-squared.
