# Air Quality Analysis and Prediction in the Bay Area

## Project Overview

The primary objective of the project is to develop a robust predictive model for PM2.5 concentrations in the Bay Area.

To achieve this, the project integrates and analyzes diverse datasets, including PurpleAir sensor data, OpenStreetMap (OSM) data, wildfire data, AQS measurements, Uber speed data, and weather station readings.

The workflow is structured into distinct stages: data collection and preprocessing, exploratory data analysis, data integration, feature engineering, and modeling.

---

## Project Workflow

### Data Collection and Preprocessing

-   [01_purpleair_data](docs/01_purpleair_data.md): Collects and preprocesses the PurpleAir sensor data, including handling missing timestamps and cleaning readings.
-   [02_aqs_data](docs/02_aqs_data.md): Collects and preprocesses AQS data, focusing on regulatory-grade PM2.5 measurements.
-   [03_weather_data](docs/03_weather_data.md): Collects and preprocesses weather station data, integrating temperature, humidity, wind speed, and other features.
-   [04_wildfire_data](docs/04_wildfire_data.md): Collects and preprocesses wildfire data, including proximity metrics and containment status.
-   [05_osm_data](docs/05_osm_data.md): Collects and preprocesses OpenStreetMap (OSM) data, focusing on spatial features like road networks and land use.
-   [06_uber_data](docs/06_uber_data.md): Collects and preprocesses Uber Speeds data.

---

### Exploratory Data Analysis

-   [07_eda_purpleair](docs/07_eda_purpleair.md): Explores and visualizes the PurpleAir sensor data, identifying trends and calibration differences.
-   [08_eda_aqs](docs/08_eda_aqs.md): Explores and visualizes AQS data, analyzing PM2.5 patterns and comparisons with PurpleAir data.
-   [09_eda_weather](docs/09_eda_weather.md): Explores and visualizes weather data, analyzing spatial and temporal variations.
-   [10_eda_wildfire](docs/10_eda_wildfire.md): Examines wildfire data, identifying trends in occurrences and impacts on air quality.
-   [11_eda_osm](docs/11_eda_osm.md): Explores OSM data, analyzing geographic distributions and potential influences on air quality.
-   [12_eda_uber](docs/11_eda_osm.md): Explores OSM data, analyzing geographic distributions and potential influences on air quality.

---

### Data Integration

-   [13_data_integration](docs/13_data_integration.md): Merges datasets (PurpleAir, AQS, weather, wildfire, OSM) into a single dataset for modeling.

---

### Feature Engineering

-   [14_feature_engineering](docs/14_feature_engineering.md): Develops predictive features, including lagged PM2.5 values, weather metrics, and wildfire proximity trends.

---

### Modeling

-   [15_linear_regression](docs/15_linear_regression.md): Implements a linear regression model as a baseline for PM2.5 prediction.
-   [16_tree_based_models](docs/16_tree_based_models.md): Develops tree-based models (Random Forest, XGBoost) for improved accuracy.
-   [17_ensemble_methods](docs/17_ensemble_methods.md): Explores ensemble models like stacking and blending for enhanced predictive performance.

---

## How to Use

1. Clone the repository to your local machine.
2. Install the required R packages listed in the `DESCRIPTION` or `requirements.txt` file.
3. Run each `.Rmd` file in sequence to reproduce the workflow.

---

## Data Sources

This project uses data from the PurpleAir API. Here are some useful resources for understanding the PurpleAir data:

- [PurpleAir API Documentation](https://api.purpleair.com/)
- [Sensor Fields](https://api.purpleair.com/#api-sensors-get-sensor-data)
- [Field Descriptions](https://community.purpleair.com/t/api-history-fields-descriptions/4652)

## Spatial Data

This project uses spatial data with the following Coordinate Reference Systems (CRS):

- CRS 4326: WGS 84 (latitude/longitude in degrees, global standard for GPS)
- CRS 3310: NAD83 / California Albers (projected in meters, used for California)

## Setup

Before running the R Markdown documents, please make sure to install the required packages by running the `setup.R` script. Open an R console and navigate to the project directory, then run the following command:

```r
source("setup.R")
```

## References

HIGHWAY DESCRIPTIONS
https://taginfo.openstreetmap.org/keys/highway#values


https://taginfo.geofabrik.de/north-america:us:california:norcal/keys/landuse#overview

OSM LAND USE CATEGORIZATION
https://osmlanduse.org/#10/-122.21682/37.73751/0/
