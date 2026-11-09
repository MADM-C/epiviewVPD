# epiviewVPD

MADM-C's epiviewVPD package provides a framework for users to create their own 
version of the Midwest EpiView: MMR Coverage and Measles Dashboard with their 
own MMR and measles data. 

epiviewVPD was developed by the [Midwest Analytics and Disease Modeling Center (MADMC)](https://www.sph.umn.edu/research/centers/midwest-analytics-and-disease-modeling/) 
at the University of Minnesota School of Public Health. It is built in **R** 
using the **Shiny** framework and integrates vaccination, geographic, and 
historical case data into a set of interactive maps and tables to support 
exploratory public health analysis and outreach. It also includes functions
to make specific visualizations separate from the RShiny/dashboard framework.

This readme covers the **basic dashboard**, which needs only three data files.
It has county and school coverage maps, a historical case map, and summary tables
and charts that show the same data in a different format. To add an additional 
facility type (such as child cares), grade-level data, school districts, or the
proximity search map, see [Adding more](vignettes/adding-more.Rmd).

**On this page:** [Requirements](#requirements) |
[Data format](#data-format) |
[Run the dashboard](#run-the-dashboard) |
[Run individual visualizations](#run-individual-visualizations)

## Requirements

- **[R 4.3.0 or newer](https://cran.r-project.org/)**
- **[RStudio](https://posit.co/download/rstudio-desktop/)** is recommended.
  Downloading reports from the dashboard needs Pandoc, which RStudio includes.
- **Internet access** to install the package, draw the background map, and
  download county boundaries the first time.

Install the package by running this in the R console. It also installs the
other R packages epiviewVPD needs, so the first install can take several
minutes.

```r
install.packages("remotes")
remotes::install_github("MADM-C/epiviewVPD", upgrade = "never")
```

## Data format

Put these three CSV files in one folder. File names and column names must
match exactly, including capitalization. The
[made-up example data](inst/extdata/example-basic/) shows the format.

| File | One row per | Required columns | Optional columns |
|---|---|---|---|
| `counties.csv` | County | `county_fips` or `county_name`, `enroll`, `full_vax_pct` | `full_vax` |
| `schools.csv` | School | `school_id`, `school_name`, `latitude`, `longitude`, `enroll`, `full_vax_pct` | `county_fips`, `county_name`, `school_type` |
| `cases.csv` | County, year, and age group | `county_fips` or `county_name`, `year`, `n_cases` | `age_group` |

County boundaries download automatically from the Census when you set your
state ([step 3](#use-your-own-data)).

| Column | What to put in it |
|---|---|
| `county_fips` | 5-character county code as text, with leading zeros (`"01001"`) |
| `county_name` | County name as the Census writes it, without the word "County" |
| `school_id` | A unique ID for each school |
| `school_name` | The name to display |
| `latitude`, `longitude` | Decimal degrees (`44.95`, `-93.09`). A school's county is found from these if you leave out its county columns |
| `enroll` | Number of students enrolled |
| `full_vax_pct` | Percent fully vaccinated: `92.4` (not `0.924`), or a range such as `>95` or `<5` |
| `full_vax` | Number fully vaccinated. Adds the overall rate above the county map |
| `school_type` | A label such as `Public` or `Private` |
| `year`, `n_cases` | Calendar year; number of cases |
| `age_group` | A label such as `0-4` or `5-17`. Don't include an all-ages total alongside the age groups |

Rules for values:

- Save CSV files as comma-separated with a header row.
- **Leave unknown values blank.** `0` means a real zero. If your data marks
  withheld values with a code such as `*`, add it to `redacted_codes` in your
  settings file ([step 2](#use-your-own-data)).
- **Keep IDs as text.** Excel removes leading zeros from codes like `01001`, so
  check them before saving.
- Write numbers without commas: `1250`, not `1,250`.

The [data format guide](vignettes/data-format.Rmd) contains an extended explanation
and guide.

## Run the dashboard

### Try the example data

Data contained in the example data is all randomly generated, including the state
and county boundaries.

```r
library(epiviewVPD)
run_dashboard(data_dir = example_data_dir())
```

The dashboard opens in a new window.

### Use your own data

**1. Make a data folder.** Create a folder named `app_data` and save
`counties.csv`, `schools.csv`, and `cases.csv` in it ([format above](#data-format)).
Put it in R's working directory; run `getwd()` to see which folder that is.

**2. Copy the settings file.** The settings file holds your state, the
dashboard title, and the text on each tab. This copies the template and opens
it:

```r
library(epiviewVPD)
file.copy(system.file("config", "template.R", package = "epiviewVPD"), "my_settings.R")
file.edit("my_settings.R")
```

**3. Set your state.** In `my_settings.R`, find the `geography` line and put in
your state's two-letter code, then save the file:

```r
geography = list(state = "WI", district_type = "unified"),
```

County boundaries for that state download the first time you run the
dashboard. Other lines marked `CHANGE`, such as the title, are optional.

**4. Start the dashboard.**

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If something in your data needs fixing, the dashboard stops and names the
file, the column, and what to change. The
[data format guide](vignettes/data-format.Rmd) has a troubleshooting table.

## Run individual visualizations

You can build each map, chart, and table without opening the dashboard. Start
by loading the data. This uses the example; your own data is covered
[below](#use-your-own-data-1).

```r
library(epiviewVPD)
data <- load_app_data(example_data_dir())
```

Then build what you need. Each one displays when you run it:

```r
# County coverage map
build_coverage_map(data$counties)

# Map of historical cases
build_cases_map(data$cases, data$counties)

# Map of the schools in one county
build_facility_map(
  schools = data$schools,
  counties = data$counties,
  selected_county = data$counties$county_name[1],
  point_type = "Schools"
)

# Cases by year, statewide
plot_epicurve(data$cases, counties = data$counties)

# Case summary table, statewide
render_cases_gt(data$cases, counties = data$counties)

# School coverage table
build_coverage_table(schools = data$schools, table_type = "school")
```

Run `?build_cases_map` (or any function name) to see its options.

### Save a visualization

```r
dir.create("outputs")

cases_chart <- plot_epicurve(data$cases, counties = data$counties)
save_figure(cases_chart, "outputs/cases.png")

coverage_map <- build_coverage_map(data$counties)
save_map(coverage_map, "outputs/coverage-map.html")

coverage_table <- build_coverage_table(schools = data$schools, table_type = "school")
save_table(coverage_table, "outputs/school-coverage.html")
```

### Use your own data

Use the `app_data` folder and `my_settings.R` file from
[Run the dashboard](#use-your-own-data). Copy this as it is. It reads your
settings and passes on the ones that change how your files are read: your
state, withheld-value codes, and age groups.

```r
library(epiviewVPD)
settings <- read_dashboard_settings("my_settings.R")

data <- load_app_data(
  "app_data",
  geography = settings$geography,
  case_data = settings$case_data,
  case_age_groups = settings$case_age_groups,
  suppressed_offset = settings$suppression$blurred_offset,
  redacted_codes = settings$suppression$redacted_codes
)
```

Then build what you need as above. Add `settings = settings` to the map and
chart functions so they use your colors and labels:

```r
build_coverage_map(data$counties, settings = settings)
plot_epicurve(data$cases, counties = data$counties, settings = settings)
```

## License

MIT; see [LICENSE.md](LICENSE.md).
