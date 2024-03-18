#' Generate Skeleton for Variable Descriptions
#'
#' Generates a skeleton code to create a dataframe containing variable names
#' and their corresponding descriptions.
#' It is designed to simplify the process of creating input for
#' \code{\link{print_data_dict}} function by providing a template for describing
#' variables in a dataset.
#'
#' @param data The dataset for which the data dictionary is to be printed.
#'
#' @return None
#' @export
#'
#' @examples
#' print_descriptions_df(mtcars)
print_descriptions_df <- function(data) {
  # Get variable names
  variables <- names(data)

  # Initialize vectors to store variable names and descriptions
  variables_txt <- paste0("'", variables, "'", collapse =
                            ",\n                                       ")
  desc_txt <- paste0("'", variables, "_description'", collapse =
                       ",\n                                         ")

  # Construct Output Text
  txt1 <- "descriptions = data.frame(Variable = c("
  txt2 <- "),\n                          Description = c("
  txt3 <- "))"

  txt <- paste0(txt1, variables_txt, txt2, desc_txt, txt3)

  # Print the output
  cat(txt)
}

#' Print Data Dictionary
#'
#' Creates a data dictionary for the dataset using attributes from the data
#' and description if provided.
#' Adapted from the data_dict_md function from the explore package.
#' Source: https://rdrr.io/cran/explore/src/R/tools.R
#'
#' @param data The dataset for which the data dictionary is to be printed.
#' @param title The title for the data dictionary (optional).
#' @param descriptions A data frame providing detailed descriptions for
#' variables (optional).
#'
#' @return None
#' @export
#'
#' @examples
#' descriptions = print_descriptions_df(mtcars)
#' print_data_dict(mtcars, title = "Cars", descriptions = descriptions)
print_data_dict <- function(data, title = "", descriptions = NULL) {
  # Load packages
  suppressPackageStartupMessages({
    if (!require("dplyr")) {
      install.packages("dplyr")
      library(dplyr)
    }
  })
  ##################
  # Get Table Data #
  ##################

  num_rows <- nrow(data)
  variables <- names(data)
  types <- sapply(data, function(x) class(x)[1])
  nas <- colSums(is.na(data))
  nas_pct <- round(nas / num_rows * 100, 1)
  unique_vals <- sapply(data, function(x) length(unique(x)))

  # Create the data dictionary table
  dict_table <- data.frame(
    "Variable" = variables,
    "Type" = types,
    "NA" = nas,
    `%NA` = nas_pct,
    "Unique" = unique_vals,
    check.names = FALSE
  )

  ####################
  # Add Descriptions #
  ####################

  # Join detailed descriptions
  if (!is.null(descriptions)) {
    descriptions$Variable <- as.character(descriptions$Variable)
    descriptions$Description <- as.character(descriptions$Description)
    dict_table <- dict_table %>% dplyr::left_join(descriptions, by = "Variable")
  } else {
    dict_table$Description <- ""
  }

  # Convert data dict table to markdown
  md_dict <- knitr::kable(dict_table, format = "markdown")
  md_dict <- paste(md_dict, collapse = "\n")

  #########################
  # Construct Output Text #
  #########################

  # Initialize txt
  txt <- ""

  # Title
  if (!missing(title))  {
    txt <- paste0(txt, "## **", title, "**", "  \n")
  } else {
    # if there is no title use dataframe name
    title <- deparse(substitute(data))
    txt <- paste0(txt, "## **", title, "**", "  \n")
  }

  # Number of rows
  txt <- paste0(txt, "**Number of Rows**: `", num_rows, "`\n\n")

  # Markdown table
  txt <- paste0(txt, md_dict, "\n")

  # Print the output
  cat(txt)
}
