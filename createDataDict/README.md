---
editor_options: 
  markdown: 
    wrap: 72
---

# createDataDict

<!-- badges: start -->

<!-- badges: end -->

The goal of createDataDict is to easily create a data dictionary for any
data frame.

## Installation

You can install the development version of createDataDict from
[GitHub](https://github.com/) with:

```         
# install.packages("devtools")
devtools::install_github("heba-razzak/lim-lab/createDataDict")
library(createDataDict)
```

## Example

```         
print_descriptions_df(mtcars)
```
descriptions = data.frame(Variable = c('mpg',
                                       'cyl',
                                       'disp',
                                       'hp',
                                       'drat',
                                       'wt',
                                       'qsec',
                                       'vs',
                                       'am',
                                       'gear',
                                       'carb'),
                          Description = c('mpg_description',
                                         'cyl_description',
                                         'disp_description',
                                         'hp_description',
                                         'drat_description',
                                         'wt_description',
                                         'qsec_description',
                                         'vs_description',
                                         'am_description',
                                         'gear_description',
                                         'carb_description'))

``` r
# using output from previous function, create descriptions data frame
descriptions = data.frame(Variable = c('mpg',
                                       'cyl',
                                       'disp',
                                       'hp',
                                       'drat',
                                       'wt',
                                       'qsec',
                                       'vs',
                                       'am',
                                       'gear',
                                       'carb'),
                          Description = c('mpg_description',
                                         'cyl_description',
                                         'disp_description',
                                         'hp_description',
                                         'drat_description',
                                         'wt_description',
                                         'qsec_description',
                                         'vs_description',
                                         'am_description',
                                         'gear_description',
                                         'carb_description'))
print_data_dict(mtcars, title = "Cars", descriptions = descriptions)
```

## **Cars**  
**Number of Rows**: `32`

|     |Variable |Type    | NA| %NA| Unique|Description |
|:----|:--------|:-------|--:|---:|------:|:-----------|
|mpg  |mpg      |numeric |  0|   0|     25|            |
|cyl  |cyl      |numeric |  0|   0|      3|            |
|disp |disp     |numeric |  0|   0|     27|            |
|hp   |hp       |numeric |  0|   0|     22|            |
|drat |drat     |numeric |  0|   0|     22|            |
|wt   |wt       |numeric |  0|   0|     29|            |
|qsec |qsec     |numeric |  0|   0|     30|            |
|vs   |vs       |numeric |  0|   0|      2|            |
|am   |am       |numeric |  0|   0|      2|            |
|gear |gear     |numeric |  0|   0|      3|            |
|carb |carb     |numeric |  0|   0|      6|            |
