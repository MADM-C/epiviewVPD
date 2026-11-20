# Additional Features

The core dashboard uses `counties.csv`, `schools.csv`, and `cases.csv`.
Additional files and settings enable child care, grade-level, school district,
and proximity map features.

This guide uses the `app_data` folder and `my_settings.R` file described in [Use
your own data](../README.md#use-your-own-data) in the README. See the [Format
Data](data-format.md) guide for file and variable requirements and the
[Configure Settings](settings.md) guide for editing the settings file.

## Available features

| Feature | Dashboard output | Data | Setting |
|---|---|---|---|
| [Child cares](#child-cares) | Child cares locations and vaccination coverage on the map and summary table | `facilities.csv` | `childcare_summary` |
| [Grade-level coverage](#grade-level-coverage) | Chart and table for each school with vaccination coverage by grade-level | `grades.csv` | `grade_plot`, `grade_table` |
| [School details](#school-details) | Additional details with the school map and downloadable report for a selected school | Optional variables in `schools.csv` | `facility_overview` |
| [School districts](#school-districts) | School district vaccination coverage map and school coverage tables by district | `districts.csv`, and `district_id` in `schools.csv` | None |
| [More county detail](#county-demographics) | Demographic information in county pop-ups | Optional variables in `counties.csv` | None |
| [Proximity map](#proximity-search) tab | Identify healthcare facilities and low-coverage schools and child cares near a selected address | `healthcare_centers.csv` (optional) | `proximity_map`, `proximity_table` |
| [Resources tab](#resources-tab) | FAQ, links, and case study downloads | None | `resources` |

## Enable features

In `my_settings.R`, change the relevant values in the `features` list from
`FALSE` to `TRUE`. For example:

```r
grade_plot = TRUE,           # grade-level chart (needs grades.csv)
grade_table = TRUE,          # grade-level table (needs grades.csv)
```

Save the settings file, add any required data files to `app_data`, and run the
dashboard:

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If an enabled feature requires a missing file, the dashboard stops and
identifies the file.

The default tab text describes the core dashboard. Update the relevant
settings in the `text` section of `my_settings.R`, such as `dashboard_intro`,
`summary_intro`, and `about_body`, to reflect the features you enable.

## View the full dashboard

To view all features with artificial data, create a settings file that enables
every feature and run the full example:

```r
library(epiviewVPD)
writeLines("list(features = all_features())", "all_features_settings.R")
run_dashboard(data_dir = example_data_dir("full"), config = "all_features_settings.R")
```

To locate the full artificial data files, run `example_data_dir("full")`.

## Child cares

Add `facilities.csv`, with one row per child care program. Programs appear on
the map when the file is present. Enable `childcare_summary` to add the summary
table. See `facilities.csv` in the [Format Data](data-format.md) guide for variable
requirements.

## Grade-level coverage

Add `grades.csv`, with one row per grade in each school, and turn on
`grade_plot` and `grade_table`. To see them, select a school on the Dashboard
tab. The variables are listed under `grades.csv` in the [Format
Data](data-format.md) guide.

## School details

Turn on `facility_overview` to show a details panel and report when someone
selects a school. The panel always shows the school's coverage, enrollment, and
county. These optional columns in `schools.csv` add to it:

| Column | What to put in it |
|---|---|
| `school_type` | A label such as `Public`, `Private`, or `Charter` |
| `partial_vax_pct` | Percent partly vaccinated or with no doses |
| `medical_pct`, `nonmedical_pct` | Percent with medical or nonmedical exemptions |
| `home_languages` | Languages spoken at home, such as `"English, Spanish"` |

## School districts

Add `districts.csv`, and add a `district_id` column to `schools.csv` to link
each school to its district. No setting is required. When the district data is
present, a School Districts option appears under Boundary View on the Dashboard
and Summary Figures tabs.

District boundaries download from the Census for the state in `my_settings.R`.
For Census boundaries, `district_id` is the 7-character Census district code.
You can use your own `district_boundaries.geojson` instead. The matching rules
and the variables are in the [Format
Data](data-format.md#school-districts-matching) guide.

## Proximity search

Turn on `proximity_map` and `proximity_table` to add a tab that finds
low-coverage schools and child cares near an address or school. It uses your
existing data.

To show healthcare locations on that map, add `healthcare_centers.csv` with the
columns `name`, `latitude`, and `longitude`.

## County demographics

Add these optional columns to `counties.csv` to show them in the county
pop-ups:

| Column | What to put in it |
|---|---|
| `students_of_color_pct` | Percent students of color |
| `frl_eligible_pct` | Percent eligible for free or reduced-price meals |

## Resources tab

Turn on `resources`, then fill in `faq`, `resource_links`, and `case_studies`
near the end of `my_settings.R`. Put case study files in the same folder as
`my_settings.R`. No data files are needed.

```r
faq = list(
  list(question = "Who is the tool designed for?",
       answer = "School nurses, child care directors, and public health staff.")
),
case_studies = list(
  list(label = "Targeting Measles Vaccine Outreach", file = "case_study_1.pdf")
),
resource_links = list(
  list(label = "Measles Basics", url = "https://www.example.gov/measles")
)
```

## Other settings

Logos, coverage colors and cutoffs, the map view, and the text on each tab are
described in the [Configure Settings](settings.md) guide.
