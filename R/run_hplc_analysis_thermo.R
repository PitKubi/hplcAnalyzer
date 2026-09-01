#' Full HPLC‐UV analysis pipeline for Thermo “UV_VIS_1.txt”
#'
#' @inheritParams run_hplc_analysis_agilent
#' @param sample_file Path to the Thermo UV export file.
#' @return Same list structure as run_hplc_analysis_agilent().
#' @export
run_hplc_analysis_thermo <- function(
    sample_file,
    peptide_sequence,
    post_win                = 11,
    post_p                  = 3,
    snr                     = 5,
    min_peak_dist_detect    = 10,
    min_rt_frac             = 0.3,
    max_rt_frac             = 1,
    flow_rate_ml            = 1,
    pathlength_cm           = 1,
    show_intermediate_plots = FALSE,
    signal_wavelength       = 214
) {
  # 1) read & get inj_vol (mL)
  df_raw   <- read_hplc_thermo(sample_file)
  inj_vol  <- attr(df_raw, "inj_vol_ml", 0.1)

  # 2) standardize to the 4-column hybrid schema: time, intensity, baseline, corrected
  df_hybrid <- df_raw %>%
    mutate(
      baseline  = 0,
      corrected = intensity
    )

  attr(df_hybrid, "inj_vol_ml") <- inj_vol
  # 3) optional SG debug
  if (show_intermediate_plots) {
    df_dbg <- df_hybrid %>%
      mutate(sg = signal::sgolayfilt(corrected, p = post_p, n = post_win))
    print(
      ggplot(df_dbg, aes(time, sg)) +
        geom_line() +
        labs(title = basename(sample_file),
             x = "Time (min)", y = "SG Smoothed") +
        theme_minimal()
    )
  }

  # 4) peak detection (uses your existing detect_peaks_on_smoothed)
  peak_table <- detect_peaks_on_smoothed(
    df            = df_hybrid,
    post_win      = post_win,
    post_p        = post_p,
    snr           = snr,
    min_peak_dist = min_peak_dist_detect,
    min_rt_frac   = min_rt_frac,
    max_rt_frac   = max_rt_frac
  )

  # 5) no peaks?
  if (nrow(peak_table) == 0) {
    warning("No peaks detected in Thermo file: ", basename(sample_file))
    return(list(
      df_hybrid        = df_hybrid,
      peak_table       = peak_table,
      epsilon          = NA_real_,
      concentration_uM = NA_real_,
      plot             = ggplot() +
        labs(title    = basename(sample_file),
             subtitle = "No peaks detected") +
        theme_minimal()
    ))
  }

  # 5b) Same endpoint-baseline integration as the Agilent path. A Thermo export arrives already
  # corrected by the instrument, so `corrected` and `intensity` are the same column here.
  reintegrated <- reintegrate_peaks_against_endpoint_baseline(
    peak_table, df_hybrid$time, least_corrected_trace(df_hybrid)
  )
  peak_table <- reintegrated$peak_table
  peak_geometry <- reintegrated$geometry

  # 6) ε (formula depends on detection wavelength) & concentration
  eps <- if (signal_wavelength == 280) {
    estimate_epsilon_280(peptide_sequence)
  } else {
    estimate_epsilon_214(peptide_sequence)
  }
  largest <- peak_table %>% slice_max(height, n = 1)
  conc    <- calculate_peak_conc(
    area         = largest$area,
    epsilon      = eps,
    inj_vol_ml   = inj_vol,
    flow_rate_ml = flow_rate_ml,
    pathlength_cm= pathlength_cm
  )

  # 7) final annotated plot
  peak_plot <- plot_largest_peak(
    df_hybrid   = df_hybrid,
    peak_table  = peak_table,
    sample_name = basename(sample_file),
    blank_name  = NULL,
    epsilon     = eps,
    conc_uM     = conc$c_uM,
    signal_wavelength = signal_wavelength,
    peak_geometry = peak_geometry
  )

  # 8) return exactly the same structure as your Agilent function
  list(
    peak_geometry    = peak_geometry,
    df_hybrid        = df_hybrid,
    peak_table       = peak_table,
    epsilon          = eps,
    concentration_uM = conc$c_uM,
    plot             = peak_plot
  )
}
