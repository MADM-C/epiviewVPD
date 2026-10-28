# ============================================================
# RESOURCE MODULE
# ============================================================

# This module contains code so that users can download the case
# studies that appear on the Resources tab.

resourceServer <- function(input, output, session){

output$download_cs1 <-
  downloadHandler(
    filename = "Midwest EpiView MMR Measles - Case Study 1.pdf",
    content = function(file) {
      file.copy("www/Midwest EpiView MMR Measles - Case Study 1.pdf", file)
    }
  )
output$download_cs2 <-
  downloadHandler(
    filename = "Midwest EpiView MMR Measles - Case Study 2.pdf",
    content = function(file) {
      file.copy("www/Midwest EpiView MMR Measles - Case Study 2.pdf", file)
    }
  )
output$download_cs3 <-
  downloadHandler(
    filename = "Midwest EpiView MMR Measles - Case Study 3.pdf",
    content = function(file) {
      file.copy("www/Midwest EpiView MMR Measles - Case Study 3.pdf", file)
    }
  )
}