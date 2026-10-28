library(shiny)
library(leaflet)
library(dplyr)
library(sf)

r_files <- list.files(testthat::test_path("..", "..", "R"), pattern = "\\.R$", full.names = TRUE)
invisible(lapply(r_files, source))