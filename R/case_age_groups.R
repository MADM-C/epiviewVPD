# ============================================================
# CASE AGE GROUPS
# ============================================================
# The age groups of the historical cases: the Age Group dropdown, the
# Summary tab's case table and the Summary Figures report.
#
# Settings `case_age_groups` (inst/config/template.R): the groups as
# written in the age_group column of cases.csv, in the order to show
# them, e.g. c("0-4", "5-11", "12-19", "20-49", "50+", "Unknown").
# NULL (the template's default) uses the groups found in the data,
# sorted by their first number ("0-4", "5-11", "12-19", ...); groups
# without a number, such as "Unknown", go last. The first number ignores
# units ("6 months" sorts after "5-17"), so list groups like that in the
# settings to get them in order.
#
# age_group values are trimmed of surrounding spaces when loaded.
#
# When the settings list the groups, load_app_data() stops if cases.csv
# has a group that isn't in the list (check_age_groups()).
# ============================================================

# Input:  setting = settings case_age_groups (or NULL);
#         values = age_group column of the cases
# Output: the age groups, in the order to show them
# Used by app_server(), render_cases_gt() and the Summary Figures report.
case_age_groups <- function(setting, values) {
  if (!is.null(setting)) return(as.character(setting))
  values <- trimws(as.character(values))
  groups <- unique(values[!is.na(values) & values != ""])
  first_number <- suppressWarnings(as.numeric(sub("^[^0-9]*([0-9]+(\\.[0-9]+)?).*$", "\\1", groups)))
  groups[order(is.na(first_number), first_number, groups)]
}

# Column headings for the case table: plain number ranges get "Years"
# ("0-4" -> "0-4 Years" with an en dash, "50+" -> "50+ Years"); anything
# else ("Under 5", "6 months", "Unknown") is kept as written.
age_group_labels <- function(groups) {
  plain <- grepl("^[0-9]+(-[0-9]+)?\\+?$", groups)
  labels <- groups
  labels[plain] <- paste(gsub("-", "\u2013", groups[plain]), "Years")
  labels
}

# Input:  cases.csv as read (age_group column may be missing or blank);
#         groups = settings case_age_groups (NULL: nothing to check);
#         problems = the loader's problem list (load_app_data.R)
# Output: none; adds a problem naming each age group that isn't in the
#         settings and the spreadsheet rows that have it
check_age_groups <- function(cases, groups, problems) {
  if (is.null(groups) || !"age_group" %in% names(cases)) return(invisible())
  age <- trimws(as.character(cases$age_group))
  bad <- !is.na(age) & age != "" & !age %in% groups
  if (!any(bad)) return(invisible())
  values <- unique(age[bad])
  rows <- which(bad) + 1 # spreadsheet row; row 1 is the header
  problems$add(
    "cases.csv: ", sum(bad), " row(s) have an age_group that isn't in the settings' case_age_groups: ",
    paste0("\"", utils::head(values, 5), "\"", collapse = ", "),
    if (length(values) > 5) ", ...",
    " (rows ", paste(utils::head(rows, 5), collapse = ", "), if (length(rows) > 5) ", ...",
    "; row 1 is the header). Add them to case_age_groups in the settings, or fix them in the data."
  )
}
