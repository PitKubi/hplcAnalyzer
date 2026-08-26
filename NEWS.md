# hplcAnalyzer 0.1.0

## New Features

* Initial release of hplcAnalyzer
* Interactive Shiny app for HPLC-UV data analysis (`run_hplc_app()`)
* Support for Agilent `.D` folders and Thermo UV export files
* Advanced baseline correction methods:
  - ALS (Asymmetric Least Squares)
  - Hybrid piecewise ALS
  - Align-subtract-hybrid with adaptive bridging
* Automated peak detection with Savitzky-Golay smoothing
* Sequence-specific ε₂₁₄ estimation (Kuipers & Gruppen, 2007)
* Automatic injection volume parsing from instrument files
* Manual integration with brush selection in Shiny app
* Batch processing capabilities
* CSV export of results

## Functions

### Data Import
* `read_hplc_agilent()` - Read Agilent .D folders
* `read_hplc_thermo()` - Read Thermo UV_VIS_1.txt exports

### Baseline Correction
* `baseline_als()` - Global ALS baseline correction
* `baseline_hybrid_sm()` - Piecewise ALS after blank subtraction
* `align_subtract_then_hybrid()` - Advanced alignment and correction

### Peak Detection & Analysis
* `detect_peaks_on_smoothed()` - Automated peak detection
* `filter_top_peaks()` - Filter and rank peaks
* `calculate_peak_conc()` - Calculate concentration from area
* `estimate_epsilon_214()` - Sequence-specific molar extinction coefficient

### Utilities
* `extract_sequence()` - Parse peptide sequence from filenames
* `choose_blank_prev()` - Select appropriate blank for sample
* `plot_largest_peak()` - Annotated peak visualization

### Workflows
* `run_hplc_analysis_agilent()` - Complete Agilent analysis pipeline
* `run_hplc_analysis_thermo()` - Complete Thermo analysis pipeline
* `run_hplc_app()` - Launch interactive Shiny interface

## Known Issues

None reported yet.

## Future Plans

* Support for additional instrument formats (Waters, Shimadzu)
* Peak deconvolution for overlapping peaks
* Multi-wavelength analysis
* Integration with proteomics databases
* Export to PeakML format


