# Air Quality Analysis and Prediction in the Bay Area

## Project Overview

The primary objective of the project is to develop a robust predictive model for PM2.5 concentrations in the Bay Area.

To achieve this, the project integrates and analyzes diverse datasets, including PurpleAir sensor data, OpenStreetMap (OSM) data, wildfire data, AQS measurements, Uber speed data, and weather station readings.

The workflow is structured into distinct stages: data collection and preprocessing, exploratory data analysis, data integration, feature engineering, and modeling.

---

## Project Workflow

### Data Collection and Preprocessing

1. **`01_purpleair_data.Rmd`**:
   - Collects and preprocesses the PurpleAir sensor data.

2. **`02_aqs_data.Rmd`**:
   - Collects and preprocesses the AQS data.

3. **`03_weather_data.Rmd`**:
   - Collects and preprocesses the weather data.

4. **`04_wildfire_data.Rmd`**:
   - Collects and preprocesses the wildfire data.

5. **`05_osm_data.Rmd`**:
   - Collects and preprocesses the OpenStreetMap (OSM) data.

### Exploratory Data Analysis

6. **`07_eda_purpleair.Rmd`**:
   - Explores and visualizes the PurpleAir data.

7. **`08_eda_aqs.Rmd`**:
   - Explores and visualizes the AQS data.

8. **`09_eda_weather.Rmd`**:
   - Explores and visualizes the weather data.

9. **`10_eda_wildfire.Rmd`**:
   - Explores and visualizes the wildfire data.

10. **`11_eda_osm.Rmd`**:
    - Explores and visualizes the OSM data.

### Data Integration

11. **`13_data_integration.Rmd`**:
    - Integrates the various data sources into a single dataset.

### Feature Engineering

12. **`12_feature_engineering.Rmd`**:
    - Creates new features from the integrated dataset.

### Modeling

13. **`13_linear_regression.Rmd`**:
    - Develops a linear regression model.

14. **`14_tree_based_models.Rmd`**:
    - Develops tree-based models (Random Forest, XGBoost).

15. **`15_ensemble_methods.Rmd`**:
    - Develops ensemble models (stacking, blending).

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
