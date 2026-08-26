# Installation Guide for hplcAnalyzer

This guide will walk you through installing and running the hplcAnalyzer app.

## Step 1: Install R

If you don't have R installed:

1. Go to https://cran.r-project.org/
2. Click the download link for your operating system:
   - **Windows**: Download and run the `.exe` installer
   - **Mac**: Download and open the `.pkg` installer
   - **Linux**: Follow the instructions for your distribution

3. Follow the installation wizard (default settings are fine)

## Step 2: Install RStudio (Recommended but Optional)

RStudio makes working with R easier:

1. Go to https://posit.co/download/rstudio-desktop/
2. Download the free RStudio Desktop version
3. Install it (default settings are fine)

## Step 3: Install hplcAnalyzer

Open R or RStudio and run these commands:

```r
# Install devtools (needed to install from GitHub)
install.packages("devtools")

# Install hplcAnalyzer
devtools::install_github("yourusername/hplcAnalyzer")
```

**Note:** The first time you install, it may take 5-10 minutes to download and install all required packages. This is normal!

### If you get a "compilation" warning on Windows:

If asked "Do you want to install from sources the packages which need compilation?", type `n` (no) and press Enter. Pre-compiled versions work fine.

## Step 4: Launch the App

Once installation is complete, run:

```r
library(hplcAnalyzer)
run_hplc_app()
```

The app should open in your web browser!

## Step 5: Using the App

1. **Browse for your data folder**: Click "Choose folder directory"
   - For Agilent: Select the folder containing your `.D` subfolders
   - For Thermo: Select the folder containing your `*_UV_VIS_1.txt` files

2. **Optional - Upload a CSV mapping file**: 
   - If your sequences aren't in the filenames
   - For Thermo: Create CSV with `Well` and `Peptide Sequence` columns
   - For Agilent: Create CSV with `Sample_ID` and `Peptide Sequence` columns
   - See README.md for detailed CSV format examples

3. **Click "Load samples"**: Wait while all samples are processed

4. **Review results**: 
   - Click rows in the table to view individual samples
   - Use Previous/Next buttons to navigate
   - Adjust the "Min analyte RT" slider if needed

5. **Manual integration** (if auto-detection fails):
   - Click and drag on the peak plot to select a region
   - The metrics will update automatically
   - Click "Reset integration" to go back to auto-detection

6. **Download results**: Click "Download Results CSV" when done

## Troubleshooting

### "Package 'XXX' not available"

Some packages may need to be installed from Bioconductor:

```r
if (!require("BiocManager")) install.packages("BiocManager")
BiocManager::install("chromConverter")
```

### "Unable to install package"

Try installing with dependencies:

```r
devtools::install_github("yourusername/hplcAnalyzer", dependencies = TRUE)
```

### App doesn't open in browser

The app URL should be printed in the R console (usually `http://127.0.0.1:XXXX`). Copy and paste this into your browser.

### "No matching DAD signal found" error

Your Agilent data might use different wavelengths. You can specify custom wavelengths:

```r
# For command-line usage
df <- read_hplc_agilent("path/to/sample.D", 
                        signal_wavelength = 280,  # change from 214
                        signal_ref = 360)
```

### Need more help?

Open an issue on GitHub: https://github.com/yourusername/hplcAnalyzer/issues

## Updating hplcAnalyzer

To get the latest version:

```r
devtools::install_github("yourusername/hplcAnalyzer", force = TRUE)
```

## Uninstalling

If you need to remove hplcAnalyzer:

```r
remove.packages("hplcAnalyzer")
```

