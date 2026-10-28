# ============================================================
# Create Table of Grade-Level MMR for Grade Details Module
# ============================================================

grade_level_table <- function(grade_data = NULL, school_id) {
  
  table_data <- grade_data |> 
    dplyr::filter(mde_school_id == school_id) |> # need adaptable variable names
    dplyr::select(grade, full_vax_pct, partial_vax_pct, medical_pct, nonmedical_pct) |> 
    mutate(
      grade = ifelse(grade == 0, "K", as.character(grade)),
      grade = factor(grade, levels = c("K", as.character(1:12))),
      full_num = parse_vax_num(full_vax_pct),
      full_vax_display =  dplyr::if_else(
        is.na(full_vax_pct) | full_vax_pct %in% c("", "NA"),
        "Redacted",
        format_vax_pct(full_vax_pct)
      ),
      partial_vax_display = dplyr::if_else(
        is.na(partial_vax_pct) | partial_vax_pct %in% c("", "NA"),
        "Redacted",
        format_vax_pct(partial_vax_pct)
      ),
      medical_pct = dplyr::if_else(
        is.na(medical_pct) | medical_pct %in% c("", "NA"),
        "Redacted",
        format_vax_pct(medical_pct)
      ),
      nonmedical_pct = dplyr::if_else(
        is.na(nonmedical_pct) | nonmedical_pct %in% c("", "NA"),
        "Redacted",
        format_vax_pct(nonmedical_pct)
      )
    ) |> 
    arrange(grade) |> 
    dplyr::select(grade,full_vax_display, partial_vax_display, medical_pct, nonmedical_pct)
  
  table_data |> 
    gt() |> 
    cols_label(
      grade = "Grade",
      full_vax_display = html("Fully <br>Vaccinated"),
      partial_vax_display = html("Partially Vaccinated /<br>No Doses"),
      medical_pct = html("Medical <br>Exemption"),
      nonmedical_pct = html("Non-Medical <br>Exemption")
    ) |> 
    cols_align(align = "center", columns = everything()) |> 
    cols_align(align = "left",   columns = grade) |> 
    # ---- Header: app navy ----
  tab_style(
    style = list(
      cell_fill(color = "#003865"),
      cell_text(color = "white", weight = "bold")
    ),
    locations = cells_column_labels()
  ) |> 
    
    # ---- Redacted cells ----
  tab_style(
    style = list(cell_fill(color = "#F0F0F0"), cell_text(color = "#888888", style = "italic")),
    locations = cells_body(columns = full_vax_display, rows = full_vax_display == "Redacted")
  ) |> 
    tab_style(
      style = list(cell_fill(color = "#F0F0F0"), cell_text(color = "#888888", style = "italic")),
      locations = cells_body(columns = partial_vax_display, rows = partial_vax_display == "Redacted")
    ) |> 
    tab_style(
      style = list(cell_fill(color = "#F0F0F0"), cell_text(color = "#888888", style = "italic")),
      locations = cells_body(columns = medical_pct, rows = medical_pct == "Redacted")
    ) |> 
    tab_style(
      style = list(cell_fill(color = "#F0F0F0"), cell_text(color = "#888888", style = "italic")),
      locations = cells_body(columns = nonmedical_pct, rows = nonmedical_pct == "Redacted")
    ) |> 
    
    # ---- Table options: borders and sizing ----
  tab_options(
    table.border.top.color       = "#88C5D3",
    table.border.top.width       = px(2),
    table.border.bottom.color    = "#88C5D3",
    table.border.bottom.width    = px(2),
    column_labels.border.bottom.color = "#88C5D3",
    column_labels.border.bottom.width = px(2),
    table_body.border.bottom.color    = "#88C5D3",
    table.font.size              = px(13),
    data_row.padding             = px(7),
    column_labels.padding        = px(8),
    table.background.color       = "#FFFFFF",
    footnotes.font.size          = px(11),
    row.striping.background_color = "#F7FBFC",
    row.striping.include_stub     = FALSE
  ) |> 
    opt_row_striping()
}