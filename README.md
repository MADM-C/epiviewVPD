# epiviewVPD <img src="man/figures/logo.png" align="right" height="139" alt="epiviewVPD logo" />

epiviewVPD is an R package for mapping surveillance data and school vaccination
coverage data for vaccine preventable diseases (VPDs), with an option to
implement features in an interactive dashboard. It was developed by the
[Midwest Analytics and Disease Modeling Center
(MADMC)](https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/)
at the University of Minnesota School of Public Health. The package is based on
[Midwest EpiView: MMR Coverage and Measles](http://z.umn.edu/mmr-measles) and
Midwest EpiView: Chickenpox, which are dashboards displaying Minnesota
vaccination coverage and surveillance data that were designed in collaboration
with the Minnesota Department of Health.

This README describes how to install the package, run the interactive dashboard
with the artificial data, and run it with your own data. For additional
details, review the separate guides linked below:

- **[Format Data](guides/data-format.md):** prepare and format your data files
  for use in epiviewVPD.
- **[Configure Settings](guides/settings.md):** edit the settings file to set
  your state, enable optional features, and change the dashboard text and
  appearance.
- **[Additional Features](guides/adding-more.md):** extend the dashboard with
  child care programs, grade-level coverage, school districts, and other available data
  layers.
- **[Visualizations Without the Interactive
  Dashboard](guides/visualizations.md):** build each map, chart, and table and
  save as standalone files, separate from the dashboard.
- **[Troubleshooting](guides/troubleshooting.md):** resolve installation and
  data errors, interpret warnings, and get help.

![The Dashboard tab with the artificial
data](man/figures/dashboard-coverage.jpg)

## What's in the interactive dashboard

epiviewVPD starts with a **core dashboard** that has three tabs: About,
Dashboard, and Summary Figures. Users have the option to add two more tabs:
Proximity Map and Resources. Features of each tab are outlined below:

| Dashboard Tab | What it displays |
|---|---|
| **About** | An explanation of what the dashboard shows, definitions, and notes about the data. Users have the option to write specific text for this page in the settings file. |
| **Dashboard** | A state-level map of vaccination coverage and historical cases by county, with filters for year. Users can select a county to zoom in and view the schools within that county. |
| **Summary Figures** | A table of school vaccination coverage for a selected county with a figure and table displaying historical cases by year and age group. Users can download vaccination and case data summaries as standalone reports. |
| **Proximity Map (Optional)** | A geospatial search tool that can be used to look up a school or address to identify nearby facilities with lower vaccination coverage. Results are displayed on a map and in a table, and can be downloaded as a PDF, CSV, or Excel file. |
| **Resources (Optional)** | A tab with resources for using the dashboard including FAQs and links to public health resources. |

It is recommended that users start by getting the core dashboard working before
adding in the other tabs or additional data. See the [Additional
Features](guides/adding-more.md) guide.

## Installation

### Requirements

- R version 4.5 or newer. epiviewVPD may not install on older versions of R.
- An internet connection is required to install the package, draw the
  background maps, and download your state's county boundaries the first time
  the dashboard runs.
- RStudio is recommended because it includes Pandoc, which is required to
  download reports from the dashboard.

### Install epiviewVPD

In the R Console, run:

```r
install.packages("remotes")
remotes::install_github("MADM-C/epiviewVPD", upgrade = "never")
```

The first line installs remotes, a tool for installing R packages from GitHub.
The second installs epiviewVPD and all additional R packages needed for
epiviewVPD to run. The first install can take several minutes if none of the
required R packages have been previously installed. If prompted to install
packages from source, enter `no`.

To update epiviewVPD, rerun the `install_github()` command. For installation
errors, see [Installation](guides/troubleshooting.md#installation) in the
Troubleshooting guide.

## Try the artificial data

Artificial data is included in the epiviewVPD package and can be used to test
various package functions. All of the artificial data is randomly generated,
including the state and county boundaries. In the R Console, run:

```r
library(epiviewVPD)
run_dashboard(data_dir = example_data_dir())
```

The dashboard opens in a new window. To stop the dashboard, press **Esc** in the
R Console or click **Stop**.

The core dashboard includes county and school vaccination coverage, historical
case data, summary figures, and an About tab. To view the optional features
with the artificial data (such as the Proximity Map), see
[View the full dashboard](guides/adding-more.md#view-the-full-dashboard) in the
Additional Features guide.

## Use your own data

Running the dashboard with your own data requires you to follow the data formatting guidelines required by the 
package and for you to edit/update the settings file. The two guides below include
additional information and guidance on how to do both of those steps, while this README provides the broader 
setup steps. 

1. **[Format Data](guides/data-format.md):** save your data as CSV files with
   the file names, variables, and values that epiviewVPD requires.
2. **[Configure Settings](guides/settings.md):** copy the settings template
   into the project directory, set your state, and update the dashboard text and
   features to match your data.

### Create an RStudio project

Create an RStudio project for the dashboard (**File > New Project**). The
project directory will serve as the working directory for the data files and
the settings file.

### Add data files

Create a folder named `app_data` in the project directory and add the following
CSV files:

| File | One row per | Required variables |
|---|---|---|
| `counties.csv` | County | `county_fips` or `county_name`, `enroll`, `full_vax_pct` |
| `schools.csv` | School | `school_id`, `school_name`, `latitude`, `longitude`, `enroll`, `full_vax_pct` |
| `cases.csv` | County, year, and age group | `county_fips` or `county_name`, `year`, `n_cases` |

File and variable names must match exactly, including capitalization. See the
[Format Data](guides/data-format.md) guide for variable definitions and
formatting requirements.

If working in Excel, save each sheet with **File > Save As > CSV UTF-8**. Excel drops
leading zeros from codes like `01001`, so check `county_fips` before saving.

### Configure settings

Run the R code below in the R Console to copy the settings template to the project directory and open it:

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
# In my_settings.R:
geography = list(state = "WI", district_type = "unified"),
```

The dashboard downloads county boundaries from the U.S. Census the first time it
runs, so an internet connection is required.

The settings file also controls the dashboard title, footer, and text on the
About tab. These settings are optional. Settings marked `CHANGE` are the ones
most states will want to update. The [Configure Settings](guides/settings.md)
guide describes the available settings and how to edit the file.

At this point, the project directory should have the following file organization:

```text
my-dashboard/              Project directory
├── my-dashboard.Rproj     RStudio project file
├── my_settings.R          Settings file
└── app_data/              Data files
    ├── counties.csv
    ├── schools.csv
    └── cases.csv
```
### Run the dashboard

In the R Console, run:

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If data validation fails, see [Data
errors](guides/troubleshooting.md#data-errors) in the Troubleshooting guide for
common messages and what to do.

To run the dashboard in a later session, open the project and run:

```r
library(epiviewVPD)
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

To update the dashboard data, replace the files in `app_data` and rerun the
same code.

## Visualizations without the interactive dashboard

For users who are not interested in an interactive dashboard, each map, chart,
and table can be built in R and saved as a standalone file outside of the
dashboard.

```r
library(epiviewVPD)
data <- load_app_data(example_data_dir())

build_coverage_map(data$counties)
plot_epicurve(data$cases, counties = data$counties)
```

See [Visualizations Without the Interactive
Dashboard](guides/visualizations.md) for the full list of visualization
functions and for instructions on how to use your own data.

## What's in this repository

```
epiviewVPD/
├── DESCRIPTION              Package metadata and dependencies
├── NAMESPACE                Functions exported by the package, generated by roxygen2
├── LICENSE, LICENSE.md       MIT license
├── README.md                 Package overview and instructions
├── app.R                     Runs the dashboard from the repository for development
├── epiviewVPD.Rproj          RStudio project file for package development
├── R/                        Package source code
│   ├── run_dashboard.R           Reads settings and data and starts the dashboard
│   ├── load_app_data.R           Reads and checks the data files
│   ├── input_validation.R        Validates values in each data file
│   ├── dashboard_settings.R      Default settings and feature switches
│   ├── app_ui.R                  Dashboard layout, including tabs, sidebars, and maps
│   ├── app_server.R              Connects dashboard inputs to outputs
│   ├── standalone_maps.R         Functions for building maps
│   ├── standalone_tables.R       Functions for building tables
│   ├── table_measles_functions.R Functions for case tables and charts
│   ├── save_visualizations.R     Functions for saving maps, figures, and tables
│   └── ...                       Additional files for dashboard sections and features
├── inst/
│   ├── config/
│   │   ├── template.R            Settings template for use with your data
│   │   └── measles_mn.R          Minnesota settings with all features enabled
│   ├── extdata/
│   │   ├── example-basic/        Artificial data for the core dashboard
│   │   └── example/              Artificial data for all features
│   ├── reports/                  Templates for downloadable reports
│   └── app/www/                  Logo and case study PDFs shown in the dashboard
├── man/                      Generated help pages; man/figures contains screenshots
├── tests/testthat/           Automated tests
└── guides/                   Guides linked at the top of this README
    ├── data-format.md            Data files and variable requirements
    ├── settings.md               The settings file and each setting
    ├── adding-more.md            Optional dashboard features
    ├── visualizations.md         Maps and charts without the dashboard
    └── troubleshooting.md        Common errors, warnings, and getting help
```

## Questions or problems?

See the [Troubleshooting](guides/troubleshooting.md) guide for common errors
and warnings.

- **Found a bug or something unclear?** Open an issue on [GitHub
  Issues](https://github.com/MADM-C/epiviewVPD/issues). Include the code you
  ran, the full error message, and the output of `R.version.string` and
  `packageVersion("epiviewVPD")`. Please don't attach real data; instead, use the
  included artificial data to show the problem.
- **Email:** Alternatively, you can email our team at
  [madmc@umn.edu](mailto:madmc@umn.edu)

## License

MIT; see [LICENSE.md](LICENSE.md).
