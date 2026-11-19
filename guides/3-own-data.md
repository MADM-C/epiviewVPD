# Interactive Dashboard

This guide describes how to configure and run the core interactive dashboard
with your own data. It assumes epiviewVPD is installed ([Getting
started](1-get-started.md)).

## Create an R project

Create an RStudio project for the dashboard. The project directory will serve
as the working directory for the data and setting files.

Run `getwd()` to check the working directory.

## Add data files

Create a folder named `app_data` in the newly created project directory and add
the following CSV files:

| File | One row per | Required variables |
|---|---|---|
| `counties.csv` | County | `county_fips` or `county_name`, `enroll`, `full_vax_pct` |
| `schools.csv` | School | `school_id`, `school_name`, `latitude`, `longitude`, `enroll`, `full_vax_pct` |
| `cases.csv` | County, year, and age group | `county_fips` or `county_name`, `year`, `n_cases` |

File and column names must match exactly, including capitalization. See the
[data format guide](2-data-format.md) for variable definitions and formatting
requirements.

**To practice with the artificial data files first,** run this in the R Console
instead. It makes the `app_data` folder and copies the example files into it:

```r
library(epiviewVPD)
dir.create("app_data", showWarnings = FALSE)
file.copy(list.files(example_data_dir(), full.names = TRUE), "app_data")
```

The artificial data has its own made-up county boundaries
(`county_boundaries.geojson`), so setting your state under [Configure
settings](#configure-settings) can be skipped while practicing. Before adding
your real data, delete everything in `app_data`, including that file; otherwise
the dashboard keeps using the made-up boundaries.

From Excel, save each sheet with **File > Save As > CSV UTF-8**. Excel drops
leading zeros from codes like `01001`, so check `county_fips` before saving.

## Configure settings

Copy the settings template to the project directory and open it:

```r
library(epiviewVPD)
file.copy(system.file("config", "template.R", package = "epiviewVPD"), "my_settings.R")
file.edit("my_settings.R")
```

In `my_settings.R`, locate the `geography` setting:

```r
# In my_settings.R:
geography = list(state = NULL, district_type = "unified"),
```

Replace `NULL` with your state's two-letter code in quotes, then save the file:

```r
# In my_settings.R (not the Console):
geography = list(state = "WI", district_type = "unified"),
```

The dashboard downloads county boundaries from the Census the first time it
runs, so an internet connection is required.

The settings file also controls the dashboard title, footer, and text on the
About tab. These settings are options; those marked `CHANGE` are the ones most
states will want to complete. The comments in the file describe each setting.

## Run the dashboard

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If data validation fails, see [Data errors](6-troubleshooting.md#data-errors)
in the Troubleshooting guide for common messages and what to do.

To run the dashboard in a later session, open the project and run:

```r
library(epiviewVPD)
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

To update the dashboard data, replace the files in `app_data` and rerun the
same code.

## Next steps

- [Maps and charts without the dashboard](4-visualizations.md): build and save
  each map, chart, and table with your data.
- [Adding more](5-adding-more.md): configure optional features, including child
  care programs, grade-level coverage, and school districts.
