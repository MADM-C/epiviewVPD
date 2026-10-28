list(
  app = list(
    title = "Midwest EpiView: MMR Coverage and Measles",
    last_updated = "July 29th, 2026",
    ga_id = "G-J8J0W26N3B",
    banner_logo = "UMN_horizontal-reversed-digital.svg",
    navbar_logo = "madmc_logo.png",
    footer_logo = "umn_logo.png"
  ),
  org = list(
    name = "Midwest Analytics and Disease Modeling Center (MADMC)",
    url = "https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/about/",
    email = "madmc@umn.edu"
  ),
  funding = "This work was supported by cooperative agreement CDC-RFA-FT-23-0069 from the Center for Forecasting and Outbreak Analytics of the U.S. Centers for Disease Control and Prevention (CDC). Its contents are solely the responsibility of the authors and do not necessarily represent the official views of the CDC.",
  case_years = list(min = 2010, max = 2025, selected = c(2015, 2020)),
  proximity = list(
    default_threshold = 85,
    address_placeholder = "e.g. 100 Church St SE, Minneapolis, MN, 55455"
  ),
  labels = list(
    coverage_outcome = "MMR Vaccine Coverage",
    cases_outcome = "Historical Measles Cases",
    cases_map_title = "Historical Measles Case Data",
    epicurve_title = "Measles Cases by Year",
    coverage_column = "MMR %",
    summary_heading = "MMR Vaccination and Measles Case Summary Figures",
    resource_links_heading = "Resources from the Minnesota Department of Health",
    tool_guide_heading = "Comparative Guide to Measles Analytic Tools"
  ),
  text = list(
    about_callout = "Measles is a highly contagious respiratory disease that can cause serious complications, including hospitalization and death. The measles, mumps, and rubella (MMR) vaccine is highly effective at preventing infection and is the best way to prevent illness from measles. Because measles spreads so easily, at least 95% of the population needs to be vaccinated to prevent outbreaks and protect communities across Minnesota. For more information on measles, see Minnesota Department of Health website (<a href='https://www.health.state.mn.us/diseases/measles/index.html' target='_blank' style='color:#0066cc;'>MDH</a>).",
    about_body = "This dashboard displays public data from the Minnesota Department of Health and Minnesota Department of Education. Measles case data is reported for 2010–2025. Vaccination data is reported for child cares, schools, and grade-levels when available for the 2025–2026 school year. The K-12 MMR coverage is the percent of students with 2-doses of MMR vaccine and the child care MMR coverage rate is the percent of students with 1 dose of MMR. Data may be incomplete for some locations.",
    dashboard_intro = "This tab displays measles, mumps, and rubella (MMR) vaccine coverage data for schools and child cares in Minnesota as well as historical measles case data. To use this tool, first select an outcome (either historical measles cases or vaccine coverage). For historical measles coverage, filter data by selecting the date range of cases to include and/or selecting age groups. For vaccine coverage, click on the map or select a county in the drop-down to view vaccine coverage data for schools and/or child cares in that county. To view grade-level vaccine coverage for a school, click the school on the map or select it from the drop-down.",
    summary_intro = "This tab provides figures that report MMR vaccine coverage and enrollment for all schools or child cares in a user-selected county as well as historical measles cases by year and age for that county. To use this tool, first select the outcome then select the county.",
    coverage_key = "The <strong>MMR %</strong> column shows the percentage of enrolled students or children who have received the recommended number of MMR vaccine doses and is color-coded by coverage level. The <a href='https://odphp.health.gov/healthypeople/objectives-and-data/browse-objectives/vaccination' target='_blank' rel='noopener noreferrer' style='color:#0066cc;' aria-label='Healthy People 2030 immunization objectives (opens in a new tab)'>Healthy People 2030</a> goal calls for 95% vaccine coverage among young children for early childhood immunizations. Higher coverage reduces the size and duration of outbreaks and limits both the number of children to get the disease and the number of school days missed.",
    proximity_intro = "This tool can help identify schools and child cares with low vaccination rates within a defined search area. To use this tool, first select a school/child care or enter an address. Then select a search radius in miles and define a vaccine coverage threshold. The map will display schools and child cares with vaccine coverage less than the defined threshold in red. Facilities with vaccine coverage higher than the threshold are shown in gray. Healthcare Centers and school district boundaries can be displayed for informational purposes.",
    proximity_results_note = "Results show facilities within the selected radius that have MMR vaccine coverage below the user-defined vaccine threshold.",
    resources_intro = "This tab provides resources for using the dashboard including FAQs and downloadable case studies as well as measles resources from the Minnesota Department of Health and a guide for understanding other publicly available measles analytic tools.",
    tool_guide = "MADMC created this guide to help public health departments and partners better understand all the different measles-related analytic tools available and determine which one(s) best fit their needs. Tools include data dashboards, simulators, and other advanced models and analytic tools. View the comparative guide <a href='https://z.umn.edu/measles-tool-guide' target='_blank' style='color:#0066cc;'> here. </a>"
  ),
  definitions = c(
    "MMR coverage" = "Percent of enrolled or eligible students who received the recommended measles, mumps, and rubella (MMR) vaccine doses (2 doses for K–12 schools, 1 dose for child cares).",
    "Full MMR Coverage" = "Percent of enrolled students who received the 2 recommended MMR doses.",
    "Partially vaccinated/no doses of MMR" = "Percent of students who have received 1 dose of MMR but have not yet received dose 2, or students that have not received any doses of MMR or haven’t submitted MMR records or an exemption to the school.",
    "Enrollment" = "Number of students reported by the facility in the annual immunization report.",
    "Eligible" = "Students who meet the criteria to be included in vaccination coverage reporting for a child care facility.",
    "Medical Exemption" = "Percent of enrolled students who have not received all the required MMR doses for a medical reason, authorized by a health care provider (<a href='https://www.health.state.mn.us/people/immunize/basics/exemption.html' target='_blank' style='color:#0066cc;'>MDH</a>).",
    "Non-medical Exemption" = "Percent of enrolled students who have not received all the required MMR doses due to their parent or guardian's beliefs (<a href='https://www.health.state.mn.us/people/immunize/basics/exemption.html' target='_blank' style='color:#0066cc;'>MDH</a>)."
  ),
  data_notes = c(
    "Vaccination rates reflect annual school and child care immunization data reported to MDH and may be incomplete for certain facilities or counties.",
    "Enrollment counts may differ between Minnesota Department of Education and Minnesota Department of Health records. These discrepancies are due to the timing of enrollment snapshots and differences in whether schools with the same name are split or aggregated across grade levels (e.g., elementary, middle, and high school campuses).",
    "Geospatial layers were sourced from the Minnesota Geospatial Commons.",
    "To protect privacy, data blurring standards were used. Data blurring involves reporting a range of vaccination coverage rather than a precise percentage. For example, schools or school districts that report all or almost all of their students being fully vaccinated have vaccination rates displayed as >95% or >98%. The range reported depends on the number of students enrolled in the school or school district. Data blurring is used to limit sharing private health information on individuals."
  ),
  # Must match the coverage color bins applied by the summary table server module.
  coverage_bins = list(
    list(label = "Below 85%", background = "#C62828", color = "white"),
    list(label = "85–89%", background = "orange", color = "#000"),
    list(label = "90–94%", background = "gold", color = "#000"),
    list(label = "95% and above", background = "darkgreen", color = "white")
  ),
  faq = list(
    list(
      question = "Who is the tool designed for?",
      answer = "It is primarily designed for use by school nurses, child care center directors and state and local public health staff, but the tool is available to anyone."
    ),
    list(
      question = "Why is it important?",
      answer = "MDH publishes MMR vaccine data for select grades on its website. This tool expands coverage to all grades and adds an interactive map, making it easier to spot trends quickly and by location. For example, a local public health team could use it to identify where to focus outreach efforts to improve vaccination rates countywide, especially when resources are limited."
    ),
    list(
      question = "What data are included?",
      answer = "This dashboard displays public data from MDH and the Minnesota Department of Education. Measles case data is reported for 2010–2025. Vaccination data is reported for child cares, schools, and grade-levels when available for the 2025–2026 school year. K-12 MMR coverage is the percent of students with two doses of MMR vaccine, and the child care MMR coverage is the percent of students with one dose of MMR. Data may be incomplete orunavailable for some locations."
    ),
    list(
      question = "Are schools and child cares required to report this data or is it voluntary?",
      answer = "They are required to report the data in their annual immunization report to MDH. These reports are submitted each year in the fall. The Minnesota Immunization Law <a href='https://www.revisor.mn.gov/statutes/cite/121A.15' target='_blank' style='color:#0066cc;'>Sec. 121A.15 MN Statutes</a> outlines the requirements for immunizations in Minnesota schools.The most recent vaccine specific immunization requirements are described in Minnesota Administrative <a href='https://www.revisor.mn.gov/rules/4604/' target='_blank' style='color:#0066cc;'>MN Rules Chapter: 4604.</a>"
    ),
    list(
      question = "Can children be excluded from school or child care if they are not vaccinated?",
      answer = "To enroll in or stay enrolled in a Minnesota school or child care program, families must provide immunization records or an exemption form. This helps protect children from diseases that spread easily in group settings. In 2024, Minnesota law gave child care centers the option to refuse enrollment to children with non-medical exemptions. Schools do not have the same option."
    ),
    list(
      question = "What are the implications or concerns of a site with a low MMR vaccination rate?",
      answer = "Because measles spreads so easily, at least 95% of the population needs to be vaccinated to prevent outbreaks and protect communities across Minnesota. If there were to be a measles case at a school or child care, all unvaccinated children and staff who have been exposed would need to stay home for 21 days and watch for symptoms of measles. The MMR vaccine is very effective at preventing illness. Children attending a school or child care with a low MMR vaccination rate are considered protected if they have received one MMR vaccine."
    ),
    list(
      question = "How often will the data be updated?",
      answer = "The data in the tool will be updated once a year, in the spring."
    )
  ),
  # output_id values must match the downloadHandler outputs defined in the server.
  case_studies = list(
    list(output_id = "download_cs1", label = "Targeting Measles Vaccine Outreach"),
    list(output_id = "download_cs2", label = "Clinic and School Partnership Opportunities to Increase MMR Coverage"),
    list(output_id = "download_cs3", label = "Presenting a Measles Outreach Plan to a County Board")
  ),
  resource_links = list(
    list(label = "Measles Basics", url = "https://www.health.state.mn.us/diseases/measles/basics.html"),
    list(label = "Measles Statistics", url = "https://www.health.state.mn.us/diseases/measles/stats.html"),
    list(label = "Measles Information for Health Professionals", url = "https://www.health.state.mn.us/diseases/measles/hcp/index.html")
  )
)