# ============================================================
# DASHBOARD SETTINGS TEMPLATE
# ============================================================
# A starting point for state specific settings: copy this file,
# edit it, and pass it to the dashboard.
#
#   file.copy(system.file("config", "template.R", package = "epiviewVPD"), "my_settings.R")
#   # edit my_settings.R, then:
#   run_dashboard(data_dir = "App Data", config = "my_settings.R")
#
# This is also the dashboard's default when no settings file is given.
# The wording here is neutral (no state, agency or organization named),
# so the dashboard runs as-is. Lines marked "CHANGE" are the ones most
# states will want to fill in. Anything set to NULL, or left out, is
# hidden. Logos and case study files go in the same folder as your
# settings file. inst/config/measles_mn.R shows a filled-in example.
# ============================================================

list(
  app = list(
    title = "EpiView: MMR Coverage and Measles",
    last_updated = NULL,   # CHANGE: e.g. "January 15, 2026" (shown in the footer)
    ga_id = NULL,          # Google Analytics ID, e.g. "G-XXXXXXXXXX"; NULL = no tracking
    # CHANGE: logo image files (png, svg, jpg), kept next to this settings
    # file (or a full path); NULL = no logo. E.g. navbar_logo = "logo.png"
    banner_logo = NULL,    # wide logo in a dark strip above the menu
    navbar_logo = NULL,    # small logo at the left of the menu
    footer_logo = NULL     # logo in the page footers
  ),
  # CHANGE: who made the dashboard (shown in the footer). Without a name
  # the contact line is hidden; url and email are optional.
  org = list(
    name = NULL,
    url = NULL,
    email = NULL
  ),
  funding = NULL,          # CHANGE: funding statement for the footer, or NULL
  case_years = list(min = 2010, max = 2025, selected = c(2015, 2020)),   # CHANGE: years in your case data
  proximity = list(
    default_threshold = 85,
    address_placeholder = "e.g. 123 Main St, City, ST 00000"
  ),
  # Starting view for the maps. Leave `map` out (as here) to fit the maps
  # to your county boundaries, or set e.g.
  #   map = list(center = c(lng = -94.5, lat = 46.5), zoom = 6,
  #              max_bounds = c(-105, 40, -84, 52)),
  # Footnotes about where the data come from; NULL removes a note.
  notes = list(
    nonreporting_school = "MMR vaccination coverage is unavailable for schools that did not report coverage data.",
    nonreporting_table = "Schools that did not report MMR vaccination coverage are not displayed."
  ),
  labels = list(
    coverage_outcome = "MMR Vaccine Coverage",
    cases_outcome = "Historical Measles Cases",
    cases_map_title = "Historical Measles Case Data",
    epicurve_title = "Measles Cases by Year",
    coverage_column = "MMR %",
    summary_heading = "MMR Vaccination and Measles Case Summary Figures",
    resource_links_heading = "Measles Resources",
    tool_guide_heading = "Comparative Guide to Measles Analytic Tools"
  ),
  text = list(
    # CHANGE: link to your health department's measles page
    about_callout = "Measles is a highly contagious respiratory disease that can cause serious complications, including hospitalization and death. The measles, mumps, and rubella (MMR) vaccine is highly effective at preventing infection and is the best way to prevent illness from measles. Because measles spreads so easily, at least 95% of the population needs to be vaccinated to prevent outbreaks and protect communities.",
    # CHANGE: name your data sources and the years they cover
    about_body = "This dashboard displays school and child care immunization data and historical measles case data. Vaccination data is reported for child cares, schools, and grade-levels when available. The K-12 MMR coverage is the percent of students with 2 doses of MMR vaccine and the child care MMR coverage rate is the percent of children with 1 dose of MMR. Data may be incomplete for some locations.",
    dashboard_intro = "This tab displays measles, mumps, and rubella (MMR) vaccine coverage data for schools and child cares as well as historical measles case data. To use this tool, first select an outcome (either historical measles cases or vaccine coverage). For historical measles cases, filter data by selecting the date range of cases to include and/or selecting age groups. For vaccine coverage, click on the map or select a county in the drop-down to view vaccine coverage data for schools and/or child cares in that county. To view grade-level vaccine coverage for a school, click the school on the map or select it from the drop-down.",
    summary_intro = "This tab provides figures that report MMR vaccine coverage and enrollment for all schools or child cares in a user-selected county as well as historical measles cases by year and age for that county. To use this tool, first select the outcome then select the county.",
    coverage_key = "The <strong>MMR %</strong> column shows the percentage of enrolled students or children who have received the recommended number of MMR vaccine doses and is color-coded by coverage level. The <a href='https://odphp.health.gov/healthypeople/objectives-and-data/browse-objectives/vaccination' target='_blank' rel='noopener noreferrer' style='color:#0066cc;' aria-label='Healthy People 2030 immunization objectives (opens in a new tab)'>Healthy People 2030</a> goal calls for 95% vaccine coverage among young children for early childhood immunizations. Higher coverage reduces the size and duration of outbreaks and limits both the number of children to get the disease and the number of school days missed.",
    proximity_intro = "This tool can help identify schools and child cares with low vaccination rates within a defined search area. To use this tool, first select a school/child care or enter an address. Then select a search radius in miles and define a vaccine coverage threshold. The map will display schools and child cares with vaccine coverage less than the defined threshold in red. Facilities with vaccine coverage higher than the threshold are shown in gray. Healthcare Centers and school district boundaries can be displayed for informational purposes.",
    proximity_results_note = "Results show facilities within the selected radius that have MMR vaccine coverage below the user-defined vaccine threshold.",
    resources_intro = "This tab provides resources for using the dashboard, including frequently asked questions and links to measles information.",
    # Shown under tool_guide_heading; NULL hides that section
    tool_guide = NULL
  ),
  definitions = c(
    "MMR coverage" = "Percent of enrolled or eligible students who received the recommended measles, mumps, and rubella (MMR) vaccine doses (2 doses for K–12 schools, 1 dose for child cares).",
    "Full MMR Coverage" = "Percent of enrolled students who received the 2 recommended MMR doses.",
    "Partially vaccinated/no doses of MMR" = "Percent of students who have received 1 dose of MMR but have not yet received dose 2, or students that have not received any doses of MMR or haven’t submitted MMR records or an exemption to the school.",
    "Enrollment" = "Number of students reported by the facility in the annual immunization report.",
    "Eligible" = "Students who meet the criteria to be included in vaccination coverage reporting for a child care facility.",
    "Medical Exemption" = "Percent of enrolled students who have not received all the required MMR doses for a medical reason, authorized by a health care provider.",
    "Non-medical Exemption" = "Percent of enrolled students who have not received all the required MMR doses due to their parent or guardian's beliefs."
  ),
  # CHANGE: notes on your data sources (where boundaries come from, etc.)
  data_notes = c(
    "Vaccination rates reflect annual school and child care immunization reports and may be incomplete for certain facilities or counties.",
    "To protect privacy, data blurring standards were used. Data blurring involves reporting a range of vaccination coverage rather than a precise percentage. For example, schools or school districts that report all or almost all of their students being fully vaccinated have vaccination rates displayed as >95% or >98%. The range reported depends on the number of students enrolled in the school or school district. Data blurring is used to limit sharing private health information on individuals."
  ),
  # Must match the coverage color bins applied by the summary table server module.
  coverage_bins = list(
    list(label = "Below 85%", background = "#C62828", color = "white"),
    list(label = "85–89%", background = "orange", color = "#000"),
    list(label = "90–94%", background = "gold", color = "#000"),
    list(label = "95% and above", background = "darkgreen", color = "white")
  ),
  # CHANGE: add questions about your state's reporting rules and laws
  faq = list(
    list(
      question = "Who is the tool designed for?",
      answer = "It is primarily designed for use by school nurses, child care center directors and state and local public health staff, but the tool is available to anyone."
    ),
    list(
      question = "What are the implications or concerns of a site with a low MMR vaccination rate?",
      answer = "Because measles spreads so easily, at least 95% of the population needs to be vaccinated to prevent outbreaks and protect communities. If there were a measles case at a school or child care, unvaccinated children and staff who were exposed may need to stay home and watch for symptoms of measles. The MMR vaccine is very effective at preventing illness."
    )
  ),
  # CHANGE: case study downloads on the Resources tab, each a label and a
  # file kept next to this settings file (or a full path), e.g.
  #   list(label = "Targeting Measles Vaccine Outreach", file = "case_study_1.pdf")
  case_studies = list(),
  # CHANGE: links to your health department's measles pages, e.g.
  #   list(label = "Measles Basics", url = "https://...")
  resource_links = list()
)
