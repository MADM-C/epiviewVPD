# ============================================================
# FILES NAMED IN THE SETTINGS (logos, case studies)
# ============================================================
# A settings file can name its own logo images and case study
# documents. Each name is looked for, in order:
#   1. as given, when it is a full path
#   2. next to the settings file (so a state keeps its files in the
#      same folder as its settings)
#   3. among the files that come with the package (inst/app/www)
#
# prepare_settings_files() is called by run_dashboard(). It
#   - stops with a clear message when a named file can't be found
#   - adds settings$logo_urls (banner/navbar/footer): the address the
#     page uses for each logo. Package logos are served from
#     "epiview-assets/"; a state's own logos are copied into a
#     temporary folder served as "settings-files/", so only those
#     files are published, not the rest of the settings folder.
#   - adds `path` (full path) to each case study, for its download
# ============================================================

# Input:  a file name from the settings and the settings file's folder
# Output: full path of the file; stops if it can't be found
find_settings_file <- function(file, settings_dir, what) {
  package_www <- system.file("app", "www", package = "epiviewVPD")
  candidates <- c(
    if (grepl("^(/|~|[A-Za-z]:)", file)) path.expand(file),
    file.path(settings_dir, file),
    file.path(package_www, file)
  )
  found <- candidates[file.exists(candidates) & !dir.exists(candidates)]
  if (length(found) == 0) {
    stop("Can't find the ", what, " \"", file, "\" named in the settings. ",
         "Put it next to the settings file (", settings_dir, ") or give its full path.",
         call. = FALSE)
  }
  normalizePath(found[1])
}

# Input:  settings from read_dashboard_settings() and the settings file's folder
# Output: the settings with logo_urls and case study paths added (see top)
prepare_settings_files <- function(settings, settings_dir) {
  package_www <- normalizePath(system.file("app", "www", package = "epiviewVPD"))
  served_dir <- NULL

  logo_url <- function(field) {
    file <- settings$app[[field]]
    if (is.null(file) || !nzchar(file)) return(NULL)
    path <- find_settings_file(file, settings_dir, paste0("logo (app$", field, ")"))
    if (dirname(path) == package_www) {
      return(file.path("epiview-assets", basename(path)))
    }
    if (is.null(served_dir)) {
      served_dir <<- tempfile("epiview-settings-files-")
      dir.create(served_dir)
    }
    served_name <- paste0(field, "-", basename(path))
    file.copy(path, file.path(served_dir, served_name), overwrite = TRUE)
    file.path("settings-files", served_name)
  }

  settings$logo_urls <- list(
    banner = logo_url("banner_logo"),
    navbar = logo_url("navbar_logo"),
    footer = logo_url("footer_logo")
  )
  if (!is.null(served_dir)) shiny::addResourcePath("settings-files", served_dir)

  settings$case_studies <- lapply(seq_along(settings$case_studies), function(i) {
    cs <- settings$case_studies[[i]]
    if (is.null(cs$label) || is.null(cs$file)) {
      stop("Case study ", i, " in the settings needs a label and a file.", call. = FALSE)
    }
    cs$path <- find_settings_file(cs$file, settings_dir, "case study file")
    cs
  })

  settings
}
