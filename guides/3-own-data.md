# Run the dashboard with your data

These steps run the basic dashboard with your own data. They assume epiviewVPD
is installed and the example works ([Get started](1-get-started.md)).

## Step 1: Make a project folder

R reads files from its **working directory**. The easiest way to set it is an
RStudio project:

1. In RStudio, choose **File > New Project > New Directory > New Project**.
2. Name it (for example `my-dashboard`), choose where to save it, and click
   **Create Project**.

RStudio now uses that folder as the working directory. Run `getwd()` to see
its location. Next time, open the project with **File > Open Project** (or
double-click the `.Rproj` file in that folder).

## Step 2: Add your data files

In the project folder, make a folder named `app_data`: in RStudio's **Files**
pane (bottom right), click **New Folder**. Save three CSV files in it:

| File | One row per | Required columns |
|---|---|---|
| `counties.csv` | County | `county_fips` or `county_name`, `enroll`, `full_vax_pct` |
| `schools.csv` | School | `school_id`, `school_name`, `latitude`, `longitude`, `enroll`, `full_vax_pct` |
| `cases.csv` | County, year, and age group | `county_fips` or `county_name`, `year`, `n_cases` |

File names and column names must match exactly, including capitalization. The
[data format guide](2-data-format.md) explains what goes in each column.

**To practice with the made-up example files first,** run this in the Console
instead. It makes the `app_data` folder and copies the example files into it:

```r
library(epiviewVPD)
dir.create("app_data", showWarnings = FALSE)
file.copy(list.files(example_data_dir(), full.names = TRUE), "app_data")
```

The example has its own made-up county boundaries
(`county_boundaries.geojson`), so you can skip
[step 4](#step-4-set-your-state) while practicing. Before adding your real
data, delete everything in `app_data`, including that file; otherwise the
dashboard keeps using the made-up boundaries.

From Excel, save each sheet with **File > Save As > CSV UTF-8**. Excel drops
leading zeros from codes like `01001`, so check `county_fips` before saving.

## Step 3: Copy the settings file

The settings file holds your state, the dashboard title, and the text on each
tab. This copies the template into your project folder and opens it:

```r
library(epiviewVPD)
file.copy(system.file("config", "template.R", package = "epiviewVPD"), "my_settings.R")
file.edit("my_settings.R")
```

## Step 4: Set your state

In `my_settings.R`, find this line. To search the file, press **Ctrl+F**
(**Cmd+F** on a Mac) and type `geography`.

```r
# In my_settings.R:
geography = list(state = NULL, district_type = "unified"),
```

Replace `NULL` with your state's two-letter code in quotes, then save the file:

```r
# In my_settings.R (not the Console):
geography = list(state = "WI", district_type = "unified"),
```

County boundaries for that state download from the Census the first time you
run the dashboard, so you need an internet connection.

The other lines in the settings file, such as the title, the footer, and the
text on the About tab, are optional. The ones most states fill in are marked
`CHANGE`, and the comments in the file explain each one.

## Step 5: Start the dashboard

```r
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

If something in your data needs fixing, the dashboard doesn't start. Instead,
the Console shows a message that names the file, the column, and what to
change. Fix the file, save it, and run the line again. The
[troubleshooting table](2-data-format.md#troubleshooting) lists the common
messages.

## Next time

Open your project in RStudio and run:

```r
library(epiviewVPD)
run_dashboard(data_dir = "app_data", config = "my_settings.R")
```

To update the data, replace the files in `app_data` and run the same lines.

## Next steps

- [Maps and charts without the dashboard](4-visualizations.md): build and save
  each map, chart, and table with your data.
- [Adding more](5-adding-more.md): child cares, grade-level coverage, school
  districts, and more.
