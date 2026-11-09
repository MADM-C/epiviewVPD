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
  withheld values with a code such as `*`, add it to `suppression$redacted_codes`
  in the settings file.
- **Keep IDs as text.** Excel removes leading zeros from codes like `01001`, so
  check them before saving.
- Write numbers without commas: `1250`, not `1,250`.

The [data format guide](vignettes/data-format.Rmd) contains an extended explanation
and guide.

## Run the dashboard

### Try the example data

Data contained in the example data is all randomly generated, included the state
and county boundaries.

```r
library(epiviewVPD)
run_dashboard(data_dir = example_data_dir())
```

The dashboard opens in a new window.

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

## License

MIT; see [LICENSE.md](LICENSE.md).
