# ============================================================
# RESOURCE MODULE
# ============================================================

# Downloads for the case studies listed on the Resources tab.
#
# Input:  case_studies from the settings, prepared by run_dashboard()
#         (settings_files.R): each a list with label, file and path
# Output: one download per case study, with the ids the Resources tab
#         uses (case_study_id() in app_ui.R); the downloaded file keeps
#         its own file name

resourceServer <- function(input, output, session, case_studies = list()) {
  for (i in seq_along(case_studies)) {
    local({
      path <- case_studies[[i]]$path
      output[[case_study_id(i)]] <- downloadHandler(
        filename = basename(path),
        content = function(file) file.copy(path, file)
      )
    })
  }
}
