# Synthetic example data

Every observation in this folder is fictional. School and child care names,
IDs, enrollment, vaccination coverage, case counts, healthcare locations,
counties, districts, and boundaries are examples for learning and testing.
They do not describe real institutions or populations.

The custom boundaries and point coordinates are located outside Minnesota.
They represent an invented geography rather than a real U.S. state's
boundaries or a particular Census vintage. A map's reference tiles may show
real background geography beneath the fictional overlays. Set
`map = list(basemap = NULL)` in your settings for a tile-free map.

The folder supplies all seven CSV layers and both GeoJSON boundary layers.
Custom district IDs such as `"0001"` are text and match the supplied district
boundaries; they are not Census district GEOIDs. County names match the
custom county boundaries. Keep these relationships intact when editing the
example. The loader uses the supplied boundary files without Census downloads.
Schools without a linked geographic district leave `district_id` blank; a
separate charter-agency identifier is not a district boundary ID. Those schools
remain available in county views and facility details.

The randomized examples should not be interpreted as measurements from an
actual report. In real data, use the same reporting population and period for
each numerator, denominator, and percentage. A supplied percentage is
displayed as reported rather than recalculated from the example counts.

`0` is a measured zero. Blank values and configured withheld-data codes mean
unknown. A `>` or `<` percentage is a reported bound, not an exact recovered
count. An absent case record counts as zero by default; use
`case_data = list(missing_records = "unknown")` when your real source may
leave out combinations that were not reported. Neither setting replaces an
explicitly blank count with zero. Optional coverage `reporting_status` values
`reported` and `not_reported` distinguish submitted reports from nonresponse.

Web links and email addresses use `example.org`, a domain reserved for
examples. Any resemblance to a real institution is coincidental.

After installing the package:

```r
library(epiviewVPD)
run_dashboard(data_dir = example_data_dir("full"))
```

To work on your own copy:

```r
dir.create("my_data", recursive = TRUE, showWarnings = FALSE)
file.copy(list.files(example_data_dir("full"), full.names = TRUE), "my_data")
```

See the [data-format guide](https://github.com/MADM-C/epiviewVPD/blob/main/vignettes/data-format.Rmd) for every
column's type, units, identifiers, missing-data rules, feature dependencies,
and a minimal dataset preparation example. The [project README](https://github.com/MADM-C/epiviewVPD#readme)
explains installation and settings. Replace fictional observations and their
boundaries together when adapting the dashboard to a real reporting source.
