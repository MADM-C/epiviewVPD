#' Save a standalone dashboard map
#'
#' Saves a Leaflet map, with its selections and analysis layers, as PNG or
#' HTML. PNG capture requires the optional webshot2 and chromote packages and a
#' Chrome or Chromium browser. Online basemaps also need network access while
#' capturing; build the map with `settings = list(map = list(basemap = NULL))`
#' to save it offline with no basemap tiles.
#'
#' HTML maps stay interactive; PNG files are static images. Keep the `_files`
#' folder next to the HTML file when copying or sharing it.
#'
#' @param map A Leaflet object returned by a standalone map constructor.
#' @param filename Destination ending in `.png` or `.html`. The parent
#'   directory must exist.
#' @param width,height Browser viewport dimensions in pixels.
#' @param zoom Image scale multiplier for PNG capture.
#' @param delay Seconds to allow widget assets to render before capture.
#' @param overwrite Whether an existing destination may be replaced.
#' @return The normalized saved file path, invisibly.
#' @export
save_map <- function(map, filename, width = 1200, height = 800,
                     zoom = 2, delay = 0.5, overwrite = FALSE) {
  if (!inherits(map, "leaflet")) {
    stop("map must be a Leaflet map object.", call. = FALSE)
  }
  destination <- export_destination(filename, c("png", "html"), overwrite)
  validate_capture_size(width, height, zoom, delay)
  require_export_package("htmlwidgets")
  if (destination$format == "png") check_capture_dependencies()

  stage <- export_staging_directory()
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  map$width <- width
  map$height <- height

  if (destination$format == "html") {
    # Supporting files go in a "_files" folder named after the HTML file.
    html_file <- file.path(stage, basename(destination$path))
    asset_name <- paste0(sub("\\.[^.]+$", "", basename(html_file)), "_files")
    asset_destination <- file.path(dirname(destination$path), asset_name)
    if (file.exists(asset_destination) && !overwrite) {
      stop("HTML dependency directory already exists: ", asset_destination,
           ". Set overwrite = TRUE to allow replacing its files.", call. = FALSE)
    }
    htmlwidgets::saveWidget(map, html_file, selfcontained = FALSE)
    asset_source <- file.path(stage, asset_name)
    if (dir.exists(asset_source) &&
        !file.copy(asset_source, dirname(destination$path), recursive = TRUE,
                   overwrite = overwrite)) {
      stop("Could not copy HTML dependencies to ", asset_destination, ".",
           call. = FALSE)
    }
    copy_export_file(html_file, destination$path, overwrite)
  } else {
    html_file <- file.path(stage, "map.html")
    image_file <- file.path(stage, "map.png")
    htmlwidgets::saveWidget(map, html_file, selfcontained = FALSE)
    capture_export(function() {
      webshot2::webshot(html_file, file = image_file, vwidth = width,
                       vheight = height, selector = ".leaflet", zoom = zoom,
                       delay = delay, quiet = TRUE)
    })
    copy_export_file(image_file, destination$path, overwrite)
  }
  invisible(destination$path)
}

#' Save a standalone dashboard figure
#'
#' Saves the ggplot given in `figure`.
#'
#' @param figure A ggplot object returned by a standalone figure constructor.
#' @param filename Destination ending in `.png` or `.pdf`. The parent
#'   directory must exist.
#' @param width,height Output dimensions in `units`.
#' @param units Dimension units: `"in"`, `"cm"`, `"mm"`, or `"px"`.
#' @param dpi Resolution for raster output, in dots per inch.
#' @param overwrite Whether an existing destination may be replaced.
#' @return The normalized saved file path, invisibly.
#' @export
save_figure <- function(figure, filename, width = 8, height = 6,
                        units = "in", dpi = 300, overwrite = FALSE) {
  if (!inherits(figure, "ggplot")) {
    stop("figure must be a ggplot object; there may be no plot for this selection.",
         call. = FALSE)
  }
  destination <- export_destination(filename, c("png", "pdf"), overwrite)
  validate_export_number(width, "width")
  validate_export_number(height, "height")
  validate_export_number(dpi, "dpi")
  units <- match.arg(units, c("in", "cm", "mm", "px"))

  stage <- export_staging_directory()
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  output_file <- file.path(stage, paste0("figure.", destination$format))
  ggplot2::ggsave(filename = output_file, plot = figure,
                  device = destination$format, width = width, height = height,
                  units = units, dpi = dpi)
  copy_export_file(output_file, destination$path, overwrite)
  invisible(destination$path)
}

#' Save a standalone dashboard table
#'
#' Saves the whole gt table, with its values, labels, footnotes and styling.
#' For proximity results, use the default static table from
#' `build_proximity_table()`, not the interactive DT table. PNG and PDF capture
#' require the optional webshot2 and chromote packages and a Chrome or Chromium
#' browser.
#'
#' @param table A gt table returned by a standalone table constructor.
#' @param filename Destination ending in `.html`, `.png`, or `.pdf`. The
#'   parent directory must exist.
#' @param width,height Browser viewport dimensions in pixels. Tables are
#'   captured in full.
#' @param zoom Image scale multiplier for PNG capture. Browser PDF printing
#'   ignores this value.
#' @param delay Seconds to allow table assets to render before capture.
#' @param overwrite Whether an existing destination may be replaced.
#' @return The normalized saved file path, invisibly.
#' @export
save_table <- function(table, filename, width = 1200, height = 800,
                       zoom = 2, delay = 0.5, overwrite = FALSE) {
  if (!inherits(table, "gt_tbl")) {
    stop("table must be a gt table object. For proximity results, use ",
         "build_proximity_table(..., interactive = FALSE).", call. = FALSE)
  }
  destination <- export_destination(filename, c("html", "png", "pdf"), overwrite)
  validate_capture_size(width, height, zoom, delay)
  if (destination$format != "html") check_capture_dependencies()

  stage <- export_staging_directory()
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  output_file <- file.path(stage, paste0("table.", destination$format))
  if (destination$format == "html") {
    gt::gtsave(table, filename = output_file, inline_css = TRUE)
  } else {
    capture_export(function() {
      gt::gtsave(table, filename = output_file, vwidth = width,
                 vheight = height, zoom = zoom, delay = delay)
    })
  }
  copy_export_file(output_file, destination$path, overwrite)
  invisible(destination$path)
}

# Checks the file name and format for save_map(), save_figure() and save_table().
export_destination <- function(filename, formats, overwrite) {
  if (!is.character(filename) || length(filename) != 1L || is.na(filename) ||
      !nzchar(filename)) {
    stop("filename must be one nonempty file path.", call. = FALSE)
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    stop("overwrite must be TRUE or FALSE.", call. = FALSE)
  }
  extension <- tolower(sub("^.*\\.", "", basename(filename)))
  if (!grepl("\\.", basename(filename)) || !extension %in% formats) {
    stop("Supported file extensions: ", paste(paste0(".", formats), collapse = ", "),
         ".", call. = FALSE)
  }
  parent <- dirname(path.expand(filename))
  if (!dir.exists(parent)) {
    stop("Destination directory does not exist: ", parent, ".", call. = FALSE)
  }
  path <- file.path(normalizePath(parent, winslash = "/", mustWork = TRUE),
                    basename(filename))
  if (dir.exists(path)) {
    stop("Destination is a directory: ", path, ".", call. = FALSE)
  }
  if (file.exists(path) && !overwrite) {
    stop("Destination already exists: ", path,
         ". Set overwrite = TRUE to replace it.", call. = FALSE)
  }
  list(path = path, format = extension)
}

validate_export_number <- function(value, name, allow_zero = FALSE) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || (if (allow_zero) value < 0 else value <= 0)) {
    stop(name, " must be one finite ", if (allow_zero) "nonnegative" else "positive",
         " number.", call. = FALSE)
  }
}

validate_capture_size <- function(width, height, zoom, delay) {
  validate_export_number(width, "width")
  validate_export_number(height, "height")
  validate_export_number(zoom, "zoom")
  validate_export_number(delay, "delay", allow_zero = TRUE)
  if (width != round(width) || height != round(height)) {
    stop("Browser width and height must be whole pixel values.", call. = FALSE)
  }
}

require_export_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("This export requires the optional ", package, " package. Install it with ",
         "install.packages(\"", package, "\").", call. = FALSE)
  }
}

check_capture_dependencies <- function() {
  require_export_package("webshot2")
  require_export_package("chromote")
  chrome <- tryCatch(chromote::find_chrome(), error = function(e) NULL)
  if (length(chrome) != 1L || is.na(chrome) || !nzchar(chrome) ||
      !file.exists(chrome)) {
    stop("PNG/PDF capture requires Chrome or a Chromium browser. Install one, ",
         "or set CHROMOTE_CHROME to its executable path.", call. = FALSE)
  }
  invisible(chrome)
}

capture_export <- function(capture) {
  tryCatch(capture(), error = function(e) {
    stop("Could not capture the visualization. Check Chrome/Chromium setup ",
         "and access to any online map tiles or other assets. ",
         conditionMessage(e), call. = FALSE)
  })
}

export_staging_directory <- function() {
  path <- tempfile("epiview-export-")
  if (!dir.create(path)) stop("Could not create an export staging directory.", call. = FALSE)
  path
}

copy_export_file <- function(source, destination, overwrite) {
  if (!file.exists(source) || !file.copy(source, destination, overwrite = overwrite)) {
    stop("Could not save visualization to ", destination, ".", call. = FALSE)
  }
  invisible(destination)
}
