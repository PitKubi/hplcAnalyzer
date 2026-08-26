# hplcAnalyzer

[![License: GPL-3](https://img.shields.io/badge/License-GPL%203-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![R](https://img.shields.io/badge/R-%3E%3D%203.6.0-blue)](https://www.r-project.org/)

Automated HPLC-UV analysis with interactive Shiny interface for peptide concentration estimation from Agilent and Thermo instruments.

## Features

- 📂 **Multi-platform support**: Agilent `.D` folders and Thermo UV export files (`.txt`)
- 📊 **Advanced baseline correction**: ALS, hybrid, and align-subtract-hybrid methods
- 🔍 **Automated peak detection**: Savitzky-Golay smoothing with SNR filtering
- 🧬 **Sequence-specific ε₂₁₄ estimation**: Based on Kuipers & Gruppen (2007)
- 💧 **Concentration calculation**: Automatic parsing of injection volumes
- 🖱️ **Interactive Shiny app**: Manual integration with brush selection
- 📦 **Batch processing**: Analyze entire directories at once
- 📥 **CSV export**: Publication-ready results tables

## Installation

### Prerequisites

Install R (≥ 3.6.0) from [CRAN](https://cran.r-project.org/)

### Install from GitHub

```r
# Install devtools if needed
if (!require("devtools")) install.packages("devtools")

# Install hplcAnalyzer
devtools::install_github("yourusername/hplcAnalyzer")
```

### Dependencies

The following packages will be installed automatically:
- chromConverter
- dplyr
- baseline
- signal
- pracma
- ggplot2
- grid
- gridExtra
- shiny
- shinyFiles
- fs
- DT

## Quick Start

### Launch the Interactive App

```r
library(hplcAnalyzer)
run_hplc_app()
```

The app will open in your default web browser.

### Basic Workflow

1. **Select folder**: Click "Choose folder directory" and navigate to your data folder
   - For Agilent: Folder containing `.D` subdirectories
   - For Thermo: Folder containing `*_UV_VIS_1.txt` files

2. **Optional: Upload CSV map**
   - For Thermo: `Well` → `Peptide Sequence` mapping
   - For Agilent: `Sample_ID` → `Peptide Sequence` mapping

3. **Load samples**: Click "Load samples" to process all files

4. **Navigate samples**: Use Previous/Next buttons or click rows in the table

5. **Manual integration** (optional): 
   - Brush-select a region on the peak plot to integrate manually
   - Click "Reset integration" to revert to auto-detection

6. **Mark bad samples**: Click "Mark as bad" to flag problematic samples

7. **Download results**: Click "Download Results CSV" to export

## Command-Line Usage

For scripted analysis without the GUI:

```r
library(hplcAnalyzer)

# Agilent analysis
result <- run_hplc_analysis_agilent(
  sample_d_path    = "path/to/sample.D",
  blank_d_path     = "path/to/blank.D",
  peptide_sequence = "TESTPEPTIDEAK",
  use_hybrid       = TRUE,
  min_rt_frac      = 0.3
)

# Thermo analysis
result <- run_hplc_analysis_thermo(
  sample_file      = "path/to/sample_UV_VIS_1.txt",
  peptide_sequence = "TESTPEPTIDEAK",
  min_rt_frac      = 0.3
)

# Access results
result$peak_table        # Detected peaks
result$concentration_uM  # Concentration in µM
result$plot              # ggplot object
```

## How It Works

### Baseline Correction

**For Agilent data with blank:**
1. **Align** blank to sample by injector peak position
2. **Subtract** blank only after injector window
3. **Bridge** positive-negative artifact pairs from over-subtraction
4. **Hybrid ALS** piecewise baseline correction with 1-min guard ramp

**For Agilent data without blank:**
- Global Asymmetric Least Squares (ALS) baseline correction

**For Thermo data:**
- Baseline subtraction already performed by instrument

### Peak Detection

1. Savitzky-Golay smoothing (11-point window, 3rd order polynomial)
2. Signal-to-noise ratio thresholding (default SNR = 5)
3. Retention time filtering (default: peaks after 30% of run)
4. Trapezoidal integration for peak areas

### Concentration Calculation

1. **ε₂₁₄ estimation** from peptide sequence:
   - Peptide bond contributions (923 M⁻¹ cm⁻¹ per bond)
   - Amino acid-specific contributions (W, Y, F, H, M, etc.)
   - Special tripeptide corrections (GGG, GPG, PGG, GGP)
   - Internal proline handling (2675 M⁻¹ cm⁻¹)

2. **Beer-Lambert calculation**:
   ```
   c (µM) = [Area (mAU·min) × Flow rate (mL/min) / 1000] / 
            [ε₂₁₄ (M⁻¹ cm⁻¹) × Pathlength (cm) × Injection volume (mL)] × 10⁶
   ```

## File Requirements

### Agilent .D Folders

Expected structure:
```
your_data_folder/
├── 001-BLANK.D/
├── 002-sample1_PEPTIDE.D/
├── 003-sample2_PEPTIDE.D/
└── 004-BLANK.D/
```

- Blank folders should contain "BLANK" in the name (case-insensitive)
- Peptide sequence parsed from trailing `_SEQUENCE.D` or via CSV mapping
- Injection volume auto-extracted from `acq.txt` (supports µL and mL)

### Thermo UV_VIS_1.txt Files

Expected filename format:
```
Sample-P1-A1_UV_VIS_1.txt
Sample-P2-H12_UV_VIS_1.txt
```

- Well ID (e.g., `P1-A1`) parsed from filename
- CSV map should contain `Well` and `Peptide Sequence` columns (case-insensitive)
- Injection volume extracted from header: `Volume (µl)\t100.00`

### CSV Mapping Files

**For Thermo:**
```csv
Well,Peptide Sequence
P1-A1,TESTPEPTIDEAK
P1-B1,ACDEFGHIK
```

**For Agilent:**
```csv
Sample_ID,Peptide Sequence
SAMPLE-20250227-097,TESTPEPTIDEAK
SAMPLE-20250227-098,ACDEFGHIK
```

**Note:** The `Sample_ID` column can also be named `MRMP`, `Sample ID`, or `Sample_Name` (case-insensitive). The ID should follow the pattern: 2-6 letters, date (YYYYMMDD), and a 3-digit number (e.g., "ABC-20250227-001").

## Advanced Options

### Baseline Correction Parameters

```r
run_hplc_analysis_agilent(
  sample_d_path     = "sample.D",
  blank_d_path      = "blank.D",
  use_hybrid        = TRUE,
  hybrid_als_lambda = 6.5,    # ALS smoothness (higher = smoother)
  hybrid_als_p      = 1e-4,   # ALS asymmetry (lower = more asymmetric)
  pre_win           = 7,      # SG pre-smoothing window
  noise_factor      = 0.1     # Noise threshold for segmentation
)
```

### Peak Detection Parameters

```r
detect_peaks_on_smoothed(
  df,
  post_win      = 11,   # SG window for smoothing
  post_p        = 3,    # SG polynomial order
  snr           = 5,    # Signal-to-noise ratio
  min_peak_dist = 10,   # Min distance between peaks (points)
  min_rt_frac   = 0.3   # Min RT as fraction of total run (0-1)
)
```

## Citation

If you use hplcAnalyzer in your research, please cite:

**ε₂₁₄ estimation method:**
> Kuipers, B. J. H., & Gruppen, H. (2007). Prediction of molar extinction coefficients of proteins and peptides using UV absorption of the constituent amino acids at 214 nm to enable quantitative reverse phase high-performance liquid chromatography−mass spectrometry analysis. *Journal of Agricultural and Food Chemistry*, 55(14), 5445-5451.

**Software:**
> [Your Name]. (2025). hplcAnalyzer: Automated HPLC-UV analysis for peptide quantification. R package version 0.1.0. https://github.com/yourusername/hplcAnalyzer

## Troubleshooting

### "No matching DAD signal found"
- Check that your Agilent data contains 214nm/360nm signals
- Modify `signal_wavelength` and `signal_ref` in `read_hplc_agilent()`

### "No peaks detected"
- Lower `snr` parameter (try 3 instead of 5)
- Reduce `min_rt_frac` slider in the app (try 20% instead of 30%)
- Check baseline correction quality in the "Raw Overlay" plot

### "Could not locate injector peaks"
- Increase `t_max` parameter in `align_subtract_then_hybrid()` (default 5 min)
- Check that injector peak occurs in first few minutes

### Encoding issues with injection volume
- Package handles UTF-16LE/BE, UTF-8, and Latin1 automatically
- If issues persist, check `acq.txt` encoding manually

## Examples

### Batch Analysis Script

```r
library(hplcAnalyzer)
library(dplyr)

# List all .D folders
samples <- list.files("data/", pattern = "\\.D$", full.names = TRUE)
blanks  <- samples[grepl("BLANK", basename(samples), ignore.case = TRUE)]
samples <- setdiff(samples, blanks)

# Process all samples
results <- lapply(samples, function(s) {
  blank <- choose_blank_prev(basename(s), blanks)
  seq   <- extract_sequence(basename(s))
  
  run_hplc_analysis_agilent(
    sample_d_path    = s,
    blank_d_path     = blank,
    peptide_sequence = seq,
    use_hybrid       = TRUE
  )
})

# Extract concentrations
conc_table <- data.frame(
  sample = basename(samples),
  conc_uM = sapply(results, function(r) r$concentration_uM)
)

write.csv(conc_table, "batch_results.csv", row.names = FALSE)
```

## License

GPL-3 © Peter Kubiniok

## Author

**Peter Kubiniok**  
Email: peterkubiniok@gmail.com

## Contributing

Issues and pull requests are welcome on [GitHub](https://github.com/yourusername/hplcAnalyzer).

## Acknowledgments

- Baseline correction: `baseline` package (Liland et al.)
- Signal processing: `signal` and `pracma` packages
- Agilent file reading: `chromConverter` package
- Interactive app: `shiny` and `shinyFiles` packages

