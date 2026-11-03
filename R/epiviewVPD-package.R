#' @keywords internal
"_PACKAGE"

# ==== Package imports ====
# Functions from these packages are used throughout R/ without the
# `package::` prefix. dataTableOutput() and renderDataTable() come
# from DT; shiny's functions with the same names are excluded.
#' @rawNamespace import(shiny, except = c(dataTableOutput, renderDataTable))
#' @importFrom DT dataTableOutput renderDataTable
#' @import leaflet
#' @import dplyr
#' @rawNamespace import(ggplot2, except = vars)
#' @import gt
#' @import sf
#' @import stringr
#' @importFrom rlang :=
#' @importFrom scales col_numeric label_number pretty_breaks
#' @importFrom stats setNames
#' @importFrom tidyr complete pivot_wider replace_na
NULL
