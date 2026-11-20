# Configure Settings

This guide describes the epiviewVPD settings file, `my_settings.R`, and how to
edit it. The settings file identifies the state displayed in the dashboard,
controls which optional features are enabled, defines how missing and withheld
values are handled, and sets the dashboard text, labels, and colors. The data
files referenced by these settings are described in the [Format
Data](data-format.md) guide.

This guide uses the `app_data` folder and `my_settings.R` file described in
[Use your own data](../README.md#use-your-own-data) in the README.

- [The settings file](#the-settings-file)
- [Copy and open the settings file](#copy-and-open-the-settings-file)
- [Edit the settings file](#edit-the-settings-file)
- [State and boundaries](#state-and-boundaries)
- [Withheld and missing values](#withheld-and-missing-values)
- [Historical case years and age groups](#historical-case-years-and-age-groups)
- [Features](#features)
- [Dashboard text and labels](#dashboard-text-and-labels)
- [Logos, colors, and map view](#logos-colors-and-map-view)
- [Check the settings file](#check-the-settings-file)
- [Minnesota example](#minnesota-example)

## The settings file

epiviewVPD includes a settings template, `template.R`, that is installed with
the package. The template is stored in the R package library rather than in the
project directory, and it is replaced each time the package is updated. For
this reason, users copy the template into their project directory as
`my_settings.R` and edit that file instead. The dashboard reads `my_settings.R`
each time it starts:

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If no settings file is provided, the dashboard uses the template's default
settings. The default settings do not specify a state, so the dashboard can
only run if the data folder includes its own `county_boundaries.geojson` file,
as the artificial data does.

The settings file is saved in the project directory, next to the `app_data`
folder:

```text
my-dashboard/              Project directory
├── my-dashboard.Rproj     RStudio project file
├── my_settings.R          Settings file
└── app_data/              Data files
```

## Copy and open the settings file

Copy the settings template to the project directory and open it:

```r
library(epiviewVPD)
file.copy(system.file("config", "template.R", package = "epiviewVPD"), "my_settings.R")
file.edit("my_settings.R")
```

If `my_settings.R` already exists in the project directory, the existing file
is not replaced.

## Edit the settings file

The settings file is an R script that contains one list of settings. Some
settings are lists that group related settings, such as `geography =
list(state = NULL, district_type = "unified")`. In-line code comments within the
file describe each setting, with settings marked `CHANGE` being the ones most users
will want to update. All other settings can be left as they are.

When the dashboard starts, the settings file is combined with the template's
default settings:

- Deleting a setting from the file restores the template's value for that
  setting.
- Setting a display item, such as a logo, a footer line, or a footnote, to
  `NULL` hides it. For other settings, `NULL` has the meaning described in the
  sections below; for example, `case_years = NULL` uses every year in the data.
- Six settings contain a list of unnamed entries: `definitions`, `data_notes`,
  `coverage_bins`, `faq`, `case_studies`, and `resource_links`. Each of these
  lists in `my_settings.R` replaces the template's list as a whole, so it must
  include every entry to be displayed.

To check the file after editing it, see [Check the settings
file](#check-the-settings-file).

## State and boundaries

`geography`, at the top of the settings file, is the only setting required to
run the dashboard with your own data. Replace `NULL` with your state's
two-letter code in quotes:

```r
geography = list(state = "WI", district_type = "unified"),
```

The dashboard downloads county and school district boundaries for this state
from the U.S. Census the first time it runs and saves a copy for later
sessions. `geography` contains two additional settings:

- `district_type`: the type of school district boundaries, `"unified"`
  (default), `"elementary"`, or `"secondary"`.
- `year`: the Census year of the boundaries, such as `year = 2023`. If `year`
  is omitted, the default year of the tigris package is used.

If the data folder includes its own `county_boundaries.geojson` or
`district_boundaries.geojson`, the dashboard draws the boundaries in that file
instead of downloading them from the Census. See [Boundary
files](data-format.md#boundary-files) in the Format Data guide.

## Withheld and missing values

The `suppression` setting describes how withheld values appear in the data:

```r
suppression = list(
  redacted_codes = character(0),
  blurred_offset = 1
),
```

- `redacted_codes`: the codes used in the data for withheld (or redacted)
  values, such as `c("*", "S")`. Cells with these codes are treated as blank.
- `blurred_offset`: the amount added to or subtracted from a blurred value,
  such as `>95` or `<5`, to assign its map color. With the default of `1`,
  `>95` is treated as 96 and `<5` as 4.

For data with exact numbers and no withheld values, set `suppression = NULL`.

The `notes` setting holds the footnotes that explain withheld and blurred
values in the dashboard. Update these notes to describe your state's
suppression rules, or set a note to `NULL` to remove it. A note on how students
were counted can also be added, such as `enrollment = "Enrollment is as of
October 1."`.

The `case_data` setting defines how missing rows in `cases.csv` are treated.
By default, a county, year, and age group without a row in `cases.csv` is
treated as having zero cases. If missing rows represent counties that did not
report, change the setting to:

```r
case_data = list(missing_records = "unknown"),
```

A blank `n_cases` value is always treated as unknown. See [Missing, zero, and
withheld values](data-format.md#missing-zero-and-withheld-values) in the Format
Data guide for how to enter these values in the data files.

## Historical case years and age groups

The `case_years` setting controls the historical cases map slider. When it is
`NULL`, the slider spans the full range of years in `cases.csv`, with every
year selected. To set the slider, give all three values: `min` and `max` are
the first and last years shown, and `selected` is the range selected when the
dashboard opens.

```r
case_years = list(min = 2015, max = 2025, selected = c(2020, 2025)),
```

The `case_age_groups` setting controls the order of age groups in the
historical case tables and charts. When it is `NULL`, groups are sorted by
their first number, with `Unknown` last. To set the order, list every age
group exactly as it is written in the `age_group` variable of `cases.csv`:

```r
case_age_groups = c("0-4", "5-17", "18+", "Unknown"),
```

If `cases.csv` contains an age group that is not listed, the dashboard stops
and names the group.

## Features

The `features` setting is a list of switches that turn each part of the
dashboard on or off. In the template, core dashboard switches are set to
`TRUE` and optional feature switches to `FALSE`. Most optional features also
require additional data files. To enable a feature, change its switch to
`TRUE`:

```r
grade_plot = TRUE,           # grade-level chart (needs grades.csv)
```

The [Additional Features](adding-more.md) guide lists each optional feature
with the data files and switches it requires. The `about` switch can also be
set to `FALSE` to hide the About tab.

The `proximity` setting controls the Proximity Map tab:

- `default_threshold`: the starting vaccination coverage threshold for the
  search.
- `address_placeholder`: the example address shown in the search box.

## Dashboard text and labels

The following settings control the text displayed in the dashboard. The
default text describes MMR vaccination coverage and measles cases; update it
to describe your own data.

| Setting | What it controls |
|---|---|
| `app$title` | Dashboard title, shown in the menu bar and in the About tab heading |
| `app$last_updated` | Date shown in the footer, such as `"January 15, 2026"` |
| `app$ga_id` | Google Analytics ID for tracking dashboard use; set to `NULL` to turn off tracking |
| `org` | Name, website, and email of the organization shown in the footer; without a name, the contact line is hidden |
| `funding` | Funding statement shown in the footer |
| `text` | Introductions at the top of each tab, the About tab text, and the color key text |
| `labels` | Names of the outcomes, map titles, chart titles, and table columns |
| `definitions` | Terms and definitions listed on the About tab |
| `data_notes` | Notes about the data sources listed on the About tab |
| `faq`, `resource_links`, `case_studies` | Content of the Resources tab; see [Resources tab](adding-more.md#resources-tab) in the Additional Features guide |

Within `text`, the `about_callout` and `about_body` settings are marked
`CHANGE` and should describe your data sources and the years they cover. When
optional features are enabled, update `dashboard_intro` and `summary_intro` to
describe them.

## Logos, colors, and map view

### Logos

The `app` setting names up to three logo images:

- `banner_logo`: a wide image above the menu.
- `navbar_logo`: a small image at the left of the menu.
- `footer_logo`: an image in the page footers.

Save each image (PNG, SVG, or JPG) in the project directory, next to
`my_settings.R`, and enter its file name:

```r
navbar_logo = "logo.png",
```

Case study files listed in `case_studies` are saved in the same location.

### Coverage colors

The `coverage_bins` setting defines the vaccination coverage cutoffs and colors
used in the maps, tables, reports, and legends. Each entry is one coverage
band, listed from lowest to highest coverage:

- `min`: the lowest coverage percentage in the band. The first band starts at
  `0`.
- `background`: the color of the band.
- `color`: the text color used on that background in the color key.
- `label` (optional): legend text for the band. Without a label, the legend
  text is created from the cutoffs.

```r
coverage_bins = list(
  list(min = 0, background = "red", color = "white"),
  list(min = 85, background = "orange", color = "#000"),
  list(min = 90, background = "gold", color = "#000"),
  list(min = 95, background = "darkgreen", color = "white")
),
```

### Map view

The `map` setting controls the background map and the starting view. By
default, the maps fit your county boundaries.

- `basemap`: the name of a Leaflet tile provider, or `NULL` for no background
  map.
- `center` and `zoom`: the starting longitude and latitude and the zoom level.
  These two are set together.
- `max_bounds`: the west, south, east, and north edges of the area the maps
  can be moved within.

```r
map = list(
  basemap = "Esri.WorldTopoMap",
  center = c(lng = -89.9, lat = 44.6), zoom = 7,
  max_bounds = c(-93, 42.4, -86.7, 47.1)
),
```

## Check the settings file

To check the settings file without starting the dashboard, run:

```r
library(epiviewVPD)
settings <- read_dashboard_settings("my_settings.R")
```

If the file contains errors, such as a value of the wrong type,
`read_dashboard_settings()` stops and lists all of them in one message. A
setting name that the dashboard does not recognize, often because of a
spelling error, produces a warning and is ignored.
`read_dashboard_settings()` does not check logo or case study files; the
dashboard checks them when it starts. See [Settings and folder
errors](troubleshooting.md#settings-and-folder-errors) in the Troubleshooting
guide for common messages and what to do.

## Minnesota example

epiviewVPD includes the settings file used for the Minnesota dashboard, with
every feature enabled. It can be used as a completed example:

```r
file.edit(system.file("config", "measles_mn.R", package = "epiviewVPD"))
```
