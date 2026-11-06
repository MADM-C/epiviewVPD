# ============================================================
# USER INTERFACE (UI) – EPIVIEW VPD DASHBOARD
# ============================================================
# Purpose
# -------
# This file defines the full user interface for the dashboard.
# It structures the layout of the application, organizes
# navigation across tabs, and creates reusable UI components
# used throughout the app.
#
# The UI is responsible only for layout and display elements.
# All data processing, mapping logic, and reactive behavior are
# implemented in the server-side modules.
#
# Input: dashboard_config, the settings list read in run_dashboard()
# (default: inst/config/template.R).
#
# Logo addresses come from settings$logo_urls, which run_dashboard() adds
# (settings_files.R): the package's own images are served from
# "epiview-assets/", a state's own logos from "settings-files/".
#
# Optional settings (logos, org, funding, last_updated, and the
# Resources tab's faq, case_studies, resource_links and tool_guide)
# are left off the page when they are NULL or empty.

# Address of a logo ("banner", "navbar" or "footer"), or NULL for none.
# Without logo_urls (settings not prepared by run_dashboard()), the file
# name is taken as one of the package's images.
logo_src <- function(settings, which) {
  if (!is.null(settings$logo_urls)) return(settings$logo_urls[[which]])
  file <- settings$app[[paste0(which, "_logo")]]
  if (!is.null(file) && nzchar(file)) file.path("epiview-assets", file)
}

# Logo image, or nothing when there is no address
logo_img <- function(src, ...) {
  if (!is.null(src)) tags$img(src = src, ...)
}

# Download button id for the i-th case study (resourceServer() makes the
# matching download)
case_study_id <- function(i) paste0("download_cs", i)

# Contact paragraph for the footers, from the settings' org entry
# (name, url, email); NULL when there is no org name
contact_paragraph <- function(org) {
  if (is.null(org$name)) return(NULL)
  if (!is.null(org$url) && !is.null(org$email)) {
    return(sprintf(
      "<strong>Contact</strong><br>
    This dashboard was created by the
    <a href='%s' target='_blank'>%s</a>.
    For questions or more information, please contact
    <a href='mailto:%s'>%s</a>.",
      org$url, org$name, org$email, org$email
    ))
  }
  creator <- if (is.null(org$url)) org$name else sprintf("<a href='%s' target='_blank'>%s</a>", org$url, org$name)
  paste0(
    "<strong>Contact</strong><br>This dashboard was created by ", creator, ".",
    if (!is.null(org$email)) sprintf(" For questions or more information, please contact <a href='mailto:%s'>%s</a>.", org$email, org$email)
  )
}

app_ui <- function(dashboard_config) {
  # === First Two Tabs Intro Paragraph ===
  intro_text_vaccine_coverage <- tags$div(
    class = "about-intro",

    # --- Callout box ONLY for first paragraph ---
    tags$div(
      class = "callout",
      HTML(dashboard_config$text$about_callout)
    ),

    # --- Normal paragraph below the box ---
    tags$p(HTML(dashboard_config$text$about_body))
  )

  # === Definitions Section ===
  definitions_block <- tags$div(
    class = "info-block",
    HTML(paste0(
      "<strong>Definitions</strong><ul>",
      paste0("<li><b>", names(dashboard_config$definitions), "</b>: ", dashboard_config$definitions, "</li>", collapse = ""),
      "</ul>"
    ))
  )

  # === Data Notes Section ===
  data_notes_block <- tags$div(
    class = "info-block",
    HTML(paste0(
      "<strong>Data Notes</strong><ul>",
      paste0("<li>", dashboard_config$data_notes, "</li>", collapse = ""),
      "</ul>"
    ))
  )

  ### Tables tab intro
  tables_intro <- tags$div(
    class = "tab-intro",
    tags$p(dashboard_config$text$summary_intro)
  )

  ### Dashboard/Tables Intro
  dashboard_tables_intro <- tags$div(
    class = "tab-intro",
    tags$p(dashboard_config$text$dashboard_intro)
  )

  # === Proximity Map Intro Paragraph ===
  intro_text_proximity_map <- tags$div(
    class = "proximity-intro",
    tags$p(HTML(dashboard_config$text$proximity_intro))
  )

  ### Resources tab intro paragraph
  resources_intro <- tags$div(
    class = "tab-intro",
    tags$p(HTML(dashboard_config$text$resources_intro))
  )

  contact_html <- contact_paragraph(dashboard_config$org)
  funding_html <- if (!is.null(dashboard_config$funding)) paste0("<strong>Funding</strong><br>", dashboard_config$funding)
  footer_text <- c(funding_html, contact_html)

  # === Shared Footer (Documentation + Logos) ===
  footer_block <- tags$div(
    class = "footer footer-main",
    tags$div(
      class = "footer-text",
      if (length(footer_text)) HTML(paste(footer_text, collapse = "<br><br>"))
    ),
    tags$div(
      class = "footer-logos",
      logo_img(logo_src(dashboard_config, "footer"))
    ),
    if (!is.null(dashboard_config$app$last_updated)) {
      tags$p(
        class = "footer-updated",
        paste("Last updated:", dashboard_config$app$last_updated)
      )
    }
  )

  resource_footer <- tags$div(
    class = "footer footer-resources",
    tags$div(
      class = "footer-text",
      if (!is.null(contact_html)) HTML(contact_html)
    ),
    tags$div(
      class = "footer-logos",
      logo_img(logo_src(dashboard_config, "footer"))
    )
  )

  # Color key on the Summary tab (settings `coverage_bins`, coverage_bands.R)
  bands <- coverage_bands(dashboard_config$coverage_bins)
  coverage_color_key <- paste(
    sprintf(
      "<span class='coverage-badge' style='background:%s; color:%s;'>%s</span>",
      bands$background, bands$color, htmltools::htmlEscape(bands$label)
    ),
    collapse = "&nbsp; "
  )

  ga_id <- dashboard_config$app$ga_id

  tagList(
    # --- Google Analytics Tag (only when the settings give an ID) ---
    if (!is.null(ga_id) && nzchar(ga_id)) {
      tags$head(
        tags$script(async = NA, src = paste0("https://www.googletagmanager.com/gtag/js?id=", ga_id)),
        tags$script(HTML(sprintf("
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', '%s');
      ", ga_id)))
      )
    },

    # --- Branding banner (settings app$banner_logo) ---
    if (!is.null(logo_src(dashboard_config, "banner"))) {
      tags$div(
        class = "top-banner",
        logo_img(logo_src(dashboard_config, "banner"))
      )
    },
    navbarPage(
      title = div(
        logo_img(logo_src(dashboard_config, "navbar"), class = "navbar-logo"),
        span(dashboard_config$app$title, class = "navbar-title")
      ),
      header = app_styles,

      # === ABOUT TAB ===
      tabPanel(
        "About",
        fluidPage(
          tags$h3(paste("About", dashboard_config$app$title)),
          tags$br(),
          intro_text_vaccine_coverage,
          definitions_block,
          data_notes_block,
          tags$hr(),
          footer_block
        )
      ),

      # === Dashboard Tab ===
      tabPanel(
        "Dashboard",
        fluidPage(
          dashboard_tables_intro,
          sidebarLayout(
            # === Sidebar for Inputs ===
            sidebarPanel(
              width = 3,

              # --- Statewide View Controls ---
              tags$div("Outcome:", class = "sidebar-heading"),
              tags$hr(),
              radioButtons(
                "map_mode",
                label = NULL,
                choices = setNames(
                  c("county", "statewide"),
                  c(dashboard_config$labels$coverage_outcome, dashboard_config$labels$cases_outcome)
                ),
                selected = "county"
              ),
              conditionalPanel(
                condition = "input.map_mode == 'statewide'",
                sliderInput(
                  "year_range", "Year Range:",
                  min = dashboard_config$case_years$min, max = dashboard_config$case_years$max,
                  value = dashboard_config$case_years$selected, sep = ""
                ),
                selectInput("case_age_group", "Age Group:", choices = NULL)
              ),

              # --- County-level Details ---
              conditionalPanel(
                condition = "input.map_mode == 'county'",

                # Toggle between county and school district view
                radioButtons("boundary_type", "Boundary View:",
                             choices = c(
                               "Counties" = "county",
                               "School Districts" = "district"
                             ),
                             selected = "county"
                ),
                conditionalPanel(
                  condition = "input.boundary_type == 'county'",
                  selectInput("selected_county", "County:", choices = NULL)
                ),
                conditionalPanel(
                  condition = "input.boundary_type == 'district'",
                  selectInput("selected_district", "School District:", choices = NULL)
                ),

                # Use radioButtons for the three choices
                radioButtons("point_type", "Show:",
                             choices = c("Schools", "Child Cares", "Schools and Child Cares"),
                             selected = "Schools"
                ),
                uiOutput("school_daycare_selector"),
                conditionalPanel(
                  condition = "input.selected_location != ''",
                  downloadButton("download_dashboard_report", "Download Summary")
                )
              )
            ),

            # === Main Panel for Outputs ===
            mainPanel(
              width = 9,
              fluidRow(
                column(
                  6,
                  conditionalPanel(
                    condition = "input.map_mode == 'county'",
                    uiOutput("county_map_title"),
                    leafletOutput("county_map", height = 500, width = "100%")
                  ),
                  conditionalPanel(
                    condition = "input.map_mode == 'statewide'",
                    h4(dashboard_config$labels$cases_map_title, class = "map-title"),
                    leafletOutput("statewide_map", height = 500, width = "100%")
                  )
                ),
                column(
                  6,
                  conditionalPanel(
                    condition = "input.map_mode == 'county' && ((input.boundary_type !== 'district' && input.selected_county !== '') || (input.boundary_type === 'district' && input.selected_district !== undefined && input.selected_district !== ''))",
                    uiOutput("submap_title"),
                    leafletOutput("sub_map", height = 500, width = "100%")
                  )
                )
              ),

              # --- County-level Details: Grade-Level Table ---
              conditionalPanel(
                condition = "input.map_mode == 'county' && ((input.boundary_type !== 'district' && input.selected_county !== '') || (input.boundary_type === 'district' && input.selected_district !== undefined && input.selected_district !== ''))",
                uiOutput("grade_demo_text"),
                tableOutput("grade_output")
              ),
              tags$hr()
            )
          )
        )
      ),

      # === GT Table Tab ===
      tabPanel(
        "Summary Figures",
        fluidPage(
          tables_intro,
          h3(dashboard_config$labels$summary_heading),
          fluidRow(
            # --- Left column: Controls ---
            column(
              width = 2,
              # Values are matched in server modules and conditionalPanel conditions; only labels come from config.
              radioButtons(
                inputId = "table_type",
                label = "Select Outcome",
                choices = setNames(
                  c("School Vaccine Coverage", "Child Care Vaccine Coverage", "Historical Measles Cases"),
                  c("School Vaccine Coverage", "Child Care Vaccine Coverage", dashboard_config$labels$cases_outcome)
                ),
                selected = "School Vaccine Coverage"
              ),
              conditionalPanel(
                condition = "input.table_type == 'School Vaccine Coverage'",
                radioButtons(
                  inputId = "gt_boundary_type",
                  label = "Boundary View:",
                  choices = c(
                    "Counties" = "county",
                    "School Districts" = "district"
                  ),
                  selected = "county"
                )
              ),
              conditionalPanel(
                condition = "(input.table_type == 'School Vaccine Coverage' && input.gt_boundary_type== 'county') || input.table_type == 'Child Care Vaccine Coverage' || input.table_type == 'Historical Measles Cases'",
                selectInput(
                  inputId = "gt_selected_county",
                  label = "County: ",
                  choices = NULL
                )
              ),
              conditionalPanel(
                condition = "input.table_type == 'School Vaccine Coverage' && input.gt_boundary_type == 'district'",
                selectInput(
                  inputId = "gt_selected_district",
                  label = "District: ",
                  choices = NULL
                )
              ),
              conditionalPanel(
                condition = "input.table_type == 'School Vaccine Coverage' ||
                   input.table_type == 'Child Care Vaccine Coverage'",
                selectInput(
                  inputId = "gt_sort_by",
                  label = "Sort Table By:",
                  choices = setNames(
                    c("full_vax_pct", "name", "total_enrollment"),
                    c(dashboard_config$labels$coverage_column, "Name", "Enrollment")
                  ),
                  selected = "full_vax_pct"
                )
              ),
              downloadButton("download_summary_figures", "Download Summary")
            ),

            # --- Right column: Epicurve FIRST, then GT table ---
            column(
              width = 10,

              # Epicurve when Measles Cases selected
              conditionalPanel(
                condition = "input.table_type == 'Historical Measles Cases'",
                tags$div(
                  class = "epicurve-panel",
                  h4(dashboard_config$labels$epicurve_title),
                  plotOutput("epi_curve", height = "350px", width = "100%"),
                  tags$hr()
                )
              ),

              # Color key explanation - shown for vaccine coverage tables
              conditionalPanel(
                condition = "input.table_type == 'School Vaccine Coverage' || input.table_type == 'Child Care Vaccine Coverage'",
                tags$div(
                  class = "color-key-intro",
                  HTML(paste0(
                    dashboard_config$text$coverage_key,
                    "<br><br><strong>Color key:</strong>&nbsp; ",
                    coverage_color_key
                  ))
                )
              ),

              # GT table always rendered
              gt_output("summary_table")
            )
          )
        )
      ),

      # === Proximity Map Tab ===
      tabPanel(
        "Proximity Map",
        fluidPage(
          intro_text_proximity_map,
          h3("School and Child Care Proximity Map"),

          # Controls section
          tags$div(
            role = "region",
            `aria-labelledby` = "controls-heading",
            tags$h4("Map Controls", id = "controls-heading", class = "sr-only"),

            # --- SECTION 1: Search Inputs (Grey Background) ---
            wellPanel(
              h4("Place a point on the map by selecting a school or a child care facility or by entering an address:", class = "proximity-search-heading"),
              fluidRow(
                column(
                  6,
                  selectInput(
                    inputId = "selected_facility",
                    label = "Select a facility:",
                    choices = c("Loading..." = ""),
                    selected = ""
                  )
                ),
                column(
                  6,
                  textInput("address_input", "Enter an address (include street, city, and zipcode):",
                            placeholder = dashboard_config$proximity$address_placeholder
                  ),
                  tags$div(
                    class = "address-search",
                    actionButton("search_address_btn", "Search Address", class = "btn-primary")
                  )
                )
              )
            ),

            # --- SECTION 2: Map Filters (White Background) ---
            fluidRow(
              class = "proximity-filters",
              column(
                6,
                sliderInput("radius_miles",
                            "Search Radius (miles):",
                            value = 10, min = .1, max = 10, step = .1
                )
              ),
              column(
                6,
                sliderInput("vaccine_threshold",
                            "Low Vaccine Threshold (%):",
                            value = dashboard_config$proximity$default_threshold, min = 0, max = 100, step = 1
                )
              )
            )
          ),

          # Results section with proper headings and labels
          tags$div(
            role = "region",
            `aria-labelledby` = "results-heading",
            tags$h4("Results", id = "results-heading", class = "sr-only"),
            fluidRow(
              column(
                6,
                tags$div(
                  role = "img",
                  `aria-label` = "Interactive map showing a chosen point and nearby schools with vaccination data",
                  leafletOutput("proximity_map", height = 600)
                )
              ),
              column(
                6,
                h4("Schools and Child Cares with Low Vaccine Coverage"),
                p(dashboard_config$text$proximity_results_note, class = "proximity-results-note"),
                tags$div(
                  role = "region",
                  `aria-label` = "Data table of schools and child cares with low vaccination rates",
                  DT::dataTableOutput("low_vaccine_table")
                )
              )
            )
          )
        )
      ),
      # === Resources Tab ===

      tabPanel(
        "Resources",
        fluidPage(
          resources_intro,
          if (length(dashboard_config$faq)) {
            tagList(
              h3("Frequently Asked Questions"),
              tags$div(
                lapply(dashboard_config$faq, function(item) {
                  tags$details(
                    tags$summary(tags$strong(item$question)),
                    p(HTML(item$answer))
                  )
                })
              )
            )
          },
          if (length(dashboard_config$case_studies)) {
            tagList(
              h3("Case Studies: Using the Dashboard in Your Work"),
              fluidRow(
                lapply(seq_along(dashboard_config$case_studies), function(i) {
                  column(4, wellPanel(
                    class = "resource-card",
                    downloadLink(outputId = case_study_id(i), label = dashboard_config$case_studies[[i]]$label)
                  ))
                })
              )
            )
          },
          if (length(dashboard_config$resource_links)) {
            tagList(
              h3(dashboard_config$labels$resource_links_heading),
              fluidRow(
                lapply(dashboard_config$resource_links, function(link) {
                  column(4, wellPanel(
                    class = "resource-card",
                    tags$div(
                      tags$a(href = link$url, target = "_blank", link$label)
                    )
                  ))
                })
              )
            )
          },
          if (!is.null(dashboard_config$text$tool_guide)) {
            tagList(
              h3(dashboard_config$labels$tool_guide_heading),
              tags$div(
                HTML(dashboard_config$text$tool_guide)
              )
            )
          }
        ),
        tags$hr(),
        resource_footer
      )
    )
  )
}
