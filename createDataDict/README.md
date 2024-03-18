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
library(createDataDict)
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

**Number of Rows**: `32` \|Variable \|Type \| NA\| %NA\|
Unique\|Description \|
\|:--------\|:-------\|--:\|---:\|------:\|:----------------\| \|mpg
\|numeric \| 0\| 0\| 25\|mpg_description \| \|cyl \|numeric \| 0\| 0\|
3\|cyl_description \| \|disp \|numeric \| 0\| 0\| 27\|disp_description
\| \|hp \|numeric \| 0\| 0\| 22\|hp_description \| \|drat \|numeric \|
0\| 0\| 22\|drat_description \| \|wt \|numeric \| 0\| 0\|
29\|wt_description \| \|qsec \|numeric \| 0\| 0\| 30\|qsec_description
\| \|vs \|numeric \| 0\| 0\| 2\|vs_description \| \|am \|numeric \| 0\|
0\| 2\|am_description \| \|gear \|numeric \| 0\| 0\| 3\|gear_description
\| \|carb \|numeric \| 0\| 0\| 6\|carb_description \|
