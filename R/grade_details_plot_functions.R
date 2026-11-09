#' Build a grade-level vaccination coverage plot
#'
#' Grade zero (or `"K"`) is kindergarten. Zero coverage is shown as zero.
#' Redacted values and records with `reporting_status = "not_reported"` are
#' shown as "Unknown". Blurred percentage labels are kept and colored by the
#' coverage bands and suppression offset.
#'
#' @param grade_data A data frame with `school_id`, `grade` and `full_vax_pct`.
#'   Percentages may be numbers or strings such as `"87.3%"`, `">95"`, or a
#'   configured redaction code. `NULL` means no grade data.
#' @param school_id The school identifier to plot.
#' @param bands Optional coverage bands. Usually left `NULL`, with `settings`
#'   given.
#' @param settings Optional dashboard settings list with `coverage_bins` and
#'   `suppression`. Without it, the dashboard defaults are used.
#' @return A `ggplot` object. Empty, redacted or nonreporting data give a plot
#'   with a message.
#' @export
#' @examples
#' grades <- data.frame(school_id = "A", grade = c(0, 1),
#'                      full_vax_pct = c("0", ">95"))
#' grade_level_plot(grades, school_id = "A")
grade_level_plot <- function(grade_data = NULL, school_id, bands = NULL, settings = NULL) {
  if (length(school_id) != 1L || is.na(school_id) || !nzchar(trimws(as.character(school_id)))) {
    stop("school_id must be one non-empty school identifier.", call. = FALSE)
  }
  if (is.null(grade_data)) return(empty_figure("Grade-level coverage is unavailable for this school."))
  if (!is.data.frame(grade_data)) stop("grade_data must be a data frame.", call. = FALSE)
  required <- c("school_id", "grade", "full_vax_pct")
  missing <- setdiff(required, names(grade_data))
  if (length(missing)) stop("grade_data is missing required columns: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  if (inherits(grade_data, "sf")) grade_data <- sf::st_drop_geometry(grade_data)
  grade_data <- grade_data[!is.na(grade_data$school_id) & as.character(grade_data$school_id) == as.character(school_id), , drop = FALSE]
  if (!nrow(grade_data)) return(empty_figure("Grade-level coverage is unavailable for this school.", grade_data))
  grade <- trimws(as.character(grade_data$grade))
  grade[grade == "0"] <- "K"
  allowed <- c("K", as.character(1:12))
  if (anyNA(grade) || any(!grade %in% allowed)) {
    stop("grade_data$grade must use 0 or K for kindergarten and 1 through 12 for other grades.", call. = FALSE)
  }
  raw <- trimws(as.character(grade_data$full_vax_pct))
  codes <- c("", "NA", "*", "S", "suppressed", "withheld", "redacted", settings$suppression$redacted_codes)
  unknown <- is.na(raw) | tolower(raw) %in% tolower(codes)
  if ("reporting_status" %in% names(grade_data)) {
    unknown <- unknown | (!is.na(grade_data$reporting_status) & grade_data$reporting_status == "not_reported")
  }
  values <- parse_vax_num(raw)
  valid_format <- valid_coverage_format(raw)
  if (any(!unknown & (!valid_format | is.na(values) | !is.finite(values) | values < 0 | values > 100))) {
    stop("grade_data$full_vax_pct must contain percentages from 0 to 100 or unknown/withheld values.", call. = FALSE)
  }
  values[unknown] <- NA_real_
  if (is.null(bands)) {
    offset <- settings$suppression$blurred_offset
    if (is.null(offset)) offset <- if ("suppression" %in% names(settings) && is.null(settings$suppression)) 0 else 1
    bands <- coverage_bands(settings$coverage_bins, offset)
  }
  grade_data$grade <- factor(grade, levels = c(as.character(12:1), "K"))
  grade_data$full_num <- values
  grade_data$full_color <- coverage_color(raw, values, bands)
  grade_data$full_color[unknown] <- NA_character_
  grade_data$full_label <- format_vax_pct(raw)
  grade_data$full_label[unknown] <- NA_character_
  if (all(is.na(values))) return(empty_figure("Grade-level coverage is unknown, withheld or not reported.", grade_data))
  labels <- grade_data[!is.na(values), , drop = FALSE]
  unknown_grades <- grade_data[is.na(values), , drop = FALSE]
  ggplot2::ggplot(grade_data, ggplot2::aes(x = grade, y = full_num, fill = full_color)) +
    ggplot2::geom_col(width = 0.6, na.rm = TRUE) +
    ggplot2::scale_fill_identity() +
    ggplot2::geom_text(data = labels, ggplot2::aes(x = grade, y = full_num, label = full_label),
                        hjust = -0.15, size = 3.8, colour = "grey20", inherit.aes = FALSE) +
    ggplot2::geom_text(data = unknown_grades, ggplot2::aes(x = grade, y = 0), label = "Unknown",
                        hjust = -0.15, size = 3.4, colour = "grey35", inherit.aes = FALSE) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(limits = c(0, max(values, na.rm = TRUE) + 18),
                                expand = ggplot2::expansion(add = c(0, 0))) +
    ggplot2::labs(x = "Grade", y = "Vaccine %") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(panel.border = ggplot2::element_rect(fill = NA, color = "#88C5D3", linewidth = 0.8),
                    plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
                    axis.title.y = ggplot2::element_text(vjust = 1.2),
                    axis.title.x = ggplot2::element_text(vjust = -0.2),
                    legend.position = "bottom", legend.direction = "horizontal",
                    legend.text = ggplot2::element_text(size = 10),
                    legend.key.size = grid::unit(0.75, "lines")) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE))
}
