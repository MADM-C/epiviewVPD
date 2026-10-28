# ============================================================
# Create Grade-Level Bar Chart (NA-safe) for Grade Details Module
# ============================================================

grade_level_plot <- function(grade_data = NULL, school_id) {
  
  grade_data <- grade_data |> 
    dplyr::filter(mde_school_id == school_id) |> 
    mutate(
      grade = ifelse(grade == 0, "K", as.character(grade)),
      grade = factor(grade, levels = c(as.character(12:1), "K")),
      # Numeric representations (NA = redacted)
      full_num = parse_vax_num(full_vax_pct),
      partial_num = parse_vax_num(partial_vax_pct),
      
      # Fill color for the full-vax segment
      full_color = coverage_color(full_vax_pct, full_num),
      
      # Label text for the full-vax value
      full_label = format_vax_pct(full_vax_pct)
    )
  
  if (all(is.na(grade_data$full_num))) {
    return(NULL)
  }
  
  ymax_data <- suppressWarnings(max(grade_data$full_num, na.rm = TRUE))
  
  if (!is.finite(ymax_data)) {
    return(NULL)
  }
  
  ymax_axis <- ymax_data + 18
  
  # ----------------------------------------------------------
  # Label data: one row per grade, anchored to the outer edge
  # of the entire stacked bar.
  # This guarantees the label is always beyond both segments
  # regardless of whether partial data exists for that grade.
  # ----------------------------------------------------------
  full_label_data <- grade_data %>%
    filter(!is.na(full_num)) %>%
    select(grade, y_pos = full_num, label = full_label)
  
  ggplot(grade_data, aes(x = grade, y = full_num, fill = full_color)) +
    geom_col(width = 0.6, na.rm = TRUE) +
    scale_fill_identity() +
    geom_text(
      data        = full_label_data,
      mapping     = aes(x = grade, y = y_pos, label = label),
      hjust       = -0.15,
      size        = 3.8,
      colour      = "grey20",
      inherit.aes = FALSE
    ) +
    coord_flip() +
    scale_y_continuous(
      limits = c(0, ymax_axis),
      expand = expansion(add = c(0, 0))) +
    labs(x = "Grade", y = "Vaccine %") +
    theme_minimal(base_size = 14) +
    theme(
      #plot.background  = element_rect(fill = "#F7FBFC", color = NA),
      #panel.background = element_rect(fill = "#FFFFFF", color = NA),
      panel.border     = element_rect(fill = NA, color = "#88C5D3", linewidth = 0.8),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      axis.title.y = element_text(vjust = 1.2),
      axis.title.x = element_text(vjust = -0.2),
      legend.position = "bottom",
      legend.direction = "horizontal",
      legend.text = element_text(size = 10),
      legend.key.size = unit(0.75, "lines")
    ) +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE))
}
