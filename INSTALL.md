# Installing hplcAnalyzer

This is the long version, written for someone who has not used R before. If you are
comfortable in R, the short version is in the [README](README.md).

## Step 1: install R

1. Go to https://cran.r-project.org/
2. Download the installer for your system.
   - **Windows**: run the `.exe`
   - **macOS**: open the `.pkg`
   - **Linux**: follow the instructions for your distribution
3. Accept the defaults.

hplcAnalyzer needs **R 4.1 or newer**. R 4.5 is fine.

## Step 2: install RStudio (optional)

RStudio is a friendlier window onto R. It is not required.
https://posit.co/download/rstudio-desktop/

## Step 3: install hplcAnalyzer

Pick whichever of these matches what you were given.

### A. You were sent a `.tar.gz` file

This is the usual route on macOS and Windows. Open R or RStudio and install the
dependencies once. This takes 5 to 10 minutes the first time and downloads a few hundred
megabytes.

```r
install.packages(c("chromConverter","dplyr","baseline","signal","pracma","ggplot2",
                   "gridExtra","shiny","shinyFiles","fs","DT","tibble","xml2","magrittr"))
```

Then install the package itself, using the full path to the file you were sent:

```r
install.packages("C:/Users/you/Downloads/hplcAnalyzer_0.7.6.tar.gz",
                 repos = NULL, type = "source")
```

On macOS the path looks like `/Users/you/Downloads/hplcAnalyzer_0.7.6.tar.gz`. Use forward
slashes on every platform, including Windows.

### B. You have a git checkout

```bash
git clone git@github.com:PitKubi/hplcAnalyzer.git
cd hplcAnalyzer
Rscript install.R
```

`install.R` installs any missing dependencies and then the package. It needs nothing but R.
From inside R or RStudio, the same thing:

```r
setwd("/path/to/hplcAnalyzer")
source("install.R")
```

### C. Straight from GitHub

While the repository is private, this needs a GitHub personal access token with the `repo`
scope. Put `GITHUB_PAT=ghp_...` in your `~/.Renviron` file, restart R, then:

```r
install.packages("remotes")
remotes::install_github("PitKubi/hplcAnalyzer", auth_token = Sys.getenv("GITHUB_PAT"))
```

Without a token, GitHub answers 404 and the install fails with a confusing "not found".

## Step 4: upgrading from an earlier version

1. **Close R and RStudio completely, then reopen.** On Windows a loaded package cannot be
   overwritten and the install fails quietly if you skip this.
2. Install any new dependency. Version 0.3.0 added `xml2`:
   ```r
   install.packages("xml2")
   ```
3. Install the new version over the old one, exactly as in Step 3. There is no need to
   uninstall first.
4. Restart R again.

Check what you ended up with:

```r
packageVersion("hplcAnalyzer")
```

## Step 5: run the app

```r
library(hplcAnalyzer)
run_hplc_app()
```

The app opens in your browser. Everything runs on your own machine and no data leaves it.
If the browser does not open, the address is printed in the R console, usually
`http://127.0.0.1:XXXX`. Paste it in yourself.

## Step 6: using the app

1. **Choose folder directory**. For Agilent, pick the folder holding your `.D` subfolders.
   For Thermo, pick the folder holding your `*_UV_VIS_N.txt` files.
2. Set the **detection wavelength**. Use 214 nm unless you have a reason not to; more than
   half of a typical peptide plate has neither Trp nor Tyr and cannot be quantified at
   280 nm at all.
3. Set the **injection volume** if your method does not inject 100 microlitres.
4. Set **Max analyte RT** to 80 percent, so the column regeneration peak at the end of the
   run is not counted. See the README for the measurement behind that number.
5. Click **Load samples** and wait while the batch is processed.
6. Click rows in the table, or use Previous and Next, to review individual runs.
7. If the detector picked the wrong peak, drag across the correct one on the lower plot to
   integrate it by hand. **Reset integration** puts it back.
8. **Download Results CSV** when done.

If the sequences in your folder names are truncated, use **Download CSV map template**,
correct the sequences in the file, upload it with **Optional CSV map**, and click
**Load samples** again.

## Troubleshooting

**"Package 'chromConverter' is not available"**
Your R is older than 4.1. Update R.

**"No matching DAD signal (214/360) found"**
That `.D` folder has no diode array signal at the requested wavelength with a 360 nm
reference. Standby, wash and diagnostic runs fail this way and can be ignored. For a real
sample, check what the method actually recorded.

**"No peaks detected"**
Lower the SNR threshold in a script (`snr = 3` instead of 5), or lower the Min analyte RT
slider. Check the upper plot to see whether the baseline correction is sensible.

**The concentration column says `NA (missing eps)`**
Either no sequence was resolved for that run, or the peptide has no chromophore at the
selected wavelength. At 280 nm that means no Trp and no Tyr, and no concentration can be
computed at all. The `Status` column in the results CSV says which.

**Something else**
The repository issue tracker is at https://github.com/PitKubi/hplcAnalyzer/issues
(private; you need access).

## Uninstalling

```r
remove.packages("hplcAnalyzer")
```
