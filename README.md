# epiviewVPD

A Shiny dashboard of school vaccine coverage and vaccine-preventable
disease cases, built by the Midwest Analytics and Disease Modeling
Center (MADMC). It was made for measles and MMR coverage in Minnesota
and is being generalized so that public health staff in other states
can run it with their own data.

## Installing

You need R 4.3.0 or newer. Install the package from GitHub:

```r
# install.packages("remotes")
remotes::install_github("MADM-C/epiviewVPD")
```

or, from a copy of this repository on your computer:

```r
# install.packages("remotes")
remotes::install_local("path/to/epiviewVPD")
```

Either way, R installs the other packages the dashboard needs.

## Running the dashboard

The dashboard reads its data from a folder. For now, that folder holds
the `.RData` files made for the Minnesota version (switching to CSV
files is in progress, #16):

| File | Objects |
|------|---------|
| `county_vaccine_data.RData` | `county_map_data`, `measles_cases`, `mn_counties` |
| `daycare_vaccine_data.RData` | `daycare_joined` |
| `school_vaccine_data.RData` | `school_demo_joined` |
| `grade_level_vaccine_data.RData` | `mmr_grade` |
| `district_vaccine_data.RData` | `school_district_data`, `district_map_data` |
| `mn_healthcare_centers.rds` | healthcare centers (`name` and point geometry) |

Then start the dashboard, pointing it at that folder:

```r
library(epiviewVPD)
run_dashboard(data_dir = "App Data")
```

It opens in your web browser. The wording, links and logos come from a
settings file; by default, the Minnesota measles settings that come with
the package. To use your own, copy that file, edit it, and pass it in:

```r
file.copy(system.file("config", "measles_mn.R", package = "epiviewVPD"), "my_settings.R")
run_dashboard(data_dir = "App Data", config = "my_settings.R")
```

To publish the dashboard (for example on shinyapps.io or Posit
Connect), put an `app.R` file next to your data folder containing:

```r
library(epiviewVPD)
run_dashboard(data_dir = "App Data")
```

## Working on the dashboard

To run the dashboard from this repository's code without installing it,
put the data in an `App Data` folder here and open `app.R` in RStudio
(the "Run App" button), or run `shiny::runApp()`. `app.R` loads the
code in `R/` with `pkgload::load_all()`.
