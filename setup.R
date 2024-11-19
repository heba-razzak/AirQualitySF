# Install packages from CRAN
cran_packages <- c("dplyr", "ggplot2", "knitr", "rmarkdown")
install.packages(cran_packages)

# Install packages from GitHub
github_packages <- c("heba-razzak/PurpleAirAPI", "heba-razzak/DataOverviewR")
devtools::install_github(github_packages)
