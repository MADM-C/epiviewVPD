# Adding more to your dashboard

[Get started](1-get-started.md) covers the basic dashboard, which needs only
`counties.csv`, `schools.csv`, and `cases.csv`. This guide covers everything
else epiviewVPD can show. Add these one at a time, once the basic dashboard is
working with your data. It uses the `app_data` folder and `my_settings.R` file
from [Run the dashboard with your data](3-own-data.md).

The columns for each file are listed in the [data format guide](2-data-format.md).

## What you can add

| Add | What you get | Data to add | Settings to turn on |
|---|---|---|---|
| [Child cares](#child-cares) | Child cares on the map, and a child care summary table | `facilities.csv` | `childcare_summary` |
| [Grade-level coverage](#grade-level-coverage) | A chart and table for each school by grade | `grades.csv` | `grade_plot`, `grade_table` |
| [School details](#school-details) | A details panel and downloadable report for a selected school | More columns in `schools.csv` (optional) | `facility_overview` |
| [School districts](#school-districts) | District maps and district summary tables | `districts.csv`, and a `district_id` column in `schools.csv` | None |
| [Proximity search](#proximity-search) | Find low-coverage schools and child cares near an address or school | `healthcare_centers.csv` (optional) | `proximity_map`, `proximity_table` |
| [More county detail](#more-county-detail) | Demographics in the county pop-ups | More columns in `counties.csv` | None |
| [Resources tab](#resources-tab) | FAQ, links, and case study downloads | None | `resources` |

## Turn a feature on

Open `my_settings.R`. The `features` list at the top has a line for each
feature. Change `FALSE` to `TRUE` for the ones you want:

```r
grade_plot = TRUE,           # grade-level chart (needs grades.csv)
grade_table = TRUE,          # grade-level table (needs grades.csv)
```

Save the file, add any data files the feature needs to `app_data`, and start the
dashboard again:

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If a feature is on and its data file is missing, the dashboard stops and names
the file.

The text on the dashboard's tabs describes the basic dashboard. When you add
features, you may want to change it, in the `text` section of `my_settings.R`
(for example `dashboard_intro`, `summary_intro`, and `about_body`).

## See everything turned on

To see the complete dashboard with the made-up example data, make a small
settings file that turns on every feature, and run it with the full example:

```r
library(epiviewVPD)
writeLines("list(features = all_features())", "all_features_settings.R")
run_dashboard(data_dir = example_data_dir("full"), config = "all_features_settings.R")
```

To find the full example files, run `example_data_dir("full")`.

## Child cares

Add `facilities.csv`, with one row per child care program. Child cares appear
on the map as soon as the file is there. Turn on `childcare_summary` to add the
summary table. The columns are listed under `facilities.csv` in the
[data format guide](2-data-format.md).

## Grade-level coverage

Add `grades.csv`, with one row per grade in each school, and turn on
`grade_plot` and `grade_table`. To see them, select a school on the Dashboard
tab. The columns are listed under `grades.csv` in the
[data format guide](2-data-format.md).

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
each school to its district. There's no setting to turn on: a "School
Districts" choice appears once the data is there.

District boundaries download from the Census for the state in `my_settings.R`.
For Census boundaries,
`district_id` is the 7-character Census district code. You can use your own
`district_boundaries.geojson` instead. The matching rules and the columns are
in the [data format guide](2-data-format.md#school-districts).

## Proximity search

Turn on `proximity_map` and `proximity_table` to add a tab that finds
low-coverage schools and child cares near an address or school. It uses your
existing data.

To show healthcare locations on that map, add `healthcare_centers.csv` with
the columns `name`, `latitude`, and `longitude`.

## More county detail

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

Every setting, including logos, coverage colors and cutoffs, and the map view,
is explained by the comments in `my_settings.R`. Lines marked `CHANGE` are the
ones most states will want to fill in. Logo files go in the same folder as
`my_settings.R`. For a filled-in example, open the Minnesota settings:

```r
file.edit(system.file("config", "measles_mn.R", package = "epiviewVPD"))
```

## Build these visualizations in R

These examples use the full example data. To use your own data, load it as in
[Use your own data](4-visualizations.md#use-your-own-data).

```r
library(epiviewVPD)
data <- load_app_data(example_data_dir("full"))
one_school <- data$schools$school_id[1]

# Grade-level chart and table for one school
grade_level_plot(data$grades, one_school)
grade_level_table(data$grades, one_school)

# Details for one school
build_facility_overview_table(
  paste0("school:", one_school),
  schools = data$schools, facilities = data$facilities,
  counties = data$counties, districts = data$districts
)

# Map with schools and child cares
build_facility_map(
  schools = data$schools, facilities = data$facilities,
  counties = data$counties, districts = data$districts
)

# District coverage map
build_coverage_map(data$districts, boundary = "district")

# Child care coverage table
build_coverage_table(facilities = data$facilities, table_type = "childcare")

# Facilities below 90% coverage within 5 miles of a point
location <- sf::st_coordinates(data$facilities)[1, ]
nearby <- analyze_facility_proximity(
  data$facilities, lat = location[["Y"]], lng = location[["X"]],
  radius_miles = 5, threshold = 90
)
build_proximity_map(
  facilities = data$facilities, counties = data$counties,
  healthcare_centers = data$healthcare_centers, result = nearby
)
build_proximity_table(nearby$low_vaccine_facilities, searched = TRUE)
```

To save a map as PNG, or a table as PNG or PDF, you also need Chrome and:

```r
install.packages(c("webshot2", "chromote"))
```
