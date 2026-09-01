#' Full HPLC-UV analysis pipeline (Agilent)
#'
#' @param sample_d_path Path to sample .D folder.
#' @param blank_d_path  Path to blank .D folder or NULL.
#' @param peptide_sequence Character. Peptide one-letter code.
#' @param sample_als_lambda Numeric. λ for global ALS baseline. Default 5.5.
#' @param sample_als_p Numeric. p for global ALS baseline. Default 1e-4.
#'   One global λ cannot both follow the injector disturbance and stay stiff under a peak, and the
#'   trade is monotone. Measured over 24 runs, as λ rises from 4 to 6.5 the baseline's climb into
#'   the main peak falls from 6.2 mAU to 0.5 while the corrected trace's offset in the first
#'   minute rises from 13 mAU to 138. 5.5 is the knee: the climb is 0.9 mAU, essentially gone, and
#'   beyond it the climb barely improves while the injector cost keeps rising.
#'
#'   Neither end of that trade changes a reported number. Areas are taken against each peak's own
#'   chord, and the injector region sits before the analyte window that `min_rt_frac` opens. What
#'   λ decides is what the overlay plot looks like and what peak detection thresholds against.
#' @param hybrid_als_lambda Numeric. λ for piecewise ALS. Default 6.5.
#' @param hybrid_als_p Numeric. p for piecewise ALS. Default 1e-4.
#' @param pre_win Integer. SG window for hybrid pre-smoothing. Default 7.
#' @param pre_p Integer. SG polynomial for hybrid pre-smoothing. Default 2.
#' @param noise_factor Numeric. Noise threshold factor for hybrid. Default 0.1.
#' @param min_peak_dist Integer. Min distance between minima for hybrid. Default 1.
#' @param min_seg_len Integer. Min segment length for hybrid. Default 20.
#' @param post_win Integer. SG window for peak detection. Default 11.
#' @param post_p Integer. SG polynomial for peak detection. Default 3.
#' @param snr Numeric. Signal-to-noise ratio threshold for peaks. Default 5.
#' @param min_peak_dist_detect Integer. Min distance between peaks. Default 10.
#' @param inj_vol_ml Numeric. Injection volume in mL. Default 0.1.
#' @param flow_rate_ml Numeric. Flow rate in mL/min. Default 1.
#' @param pathlength_cm Numeric. Cell pathlength in cm. Default 1.
#' @param show_intermediate_plots Logical. Print intermediate plots? Default FALSE.
#' @param min_rt_frac Numeric. Fraction (0–1) of total run time; peaks earlier than this are dropped. Default 0.3.
#' @param max_rt_frac Numeric. Fraction (0–1) of total run time; peaks later than this are dropped. Default 1, which keeps the whole run.
#' @return A list with elements: df_hybrid, peak_table, epsilon, concentration_uM, plot
#' @export
run_hplc_analysis_agilent <- function(
    sample_d_path,
    blank_d_path             = NULL,
    peptide_sequence,
    sample_als_lambda        = 5.5,
    sample_als_p             = 1e-4,
    use_hybrid               = FALSE,
    hybrid_als_lambda        = 6.5,
    hybrid_als_p             = 1e-4,
    pre_win                  = 7,
    pre_p                    = 2,
    noise_factor             = 0.1,
    min_peak_dist            = 1,
    min_seg_len              = 20,
    post_win                 = 11,
    post_p                   = 3,
    snr                      = 5,
    min_peak_dist_detect     = 10,
    inj_vol_ml               = 0.1,
    flow_rate_ml             = 1,
    pathlength_cm            = 1,
    show_intermediate_plots  = FALSE,
    min_rt_frac              = 0.3,
    max_rt_frac              = 1,
    signal_wavelength        = 214,
    signal_ref               = 360
) {
  # 1) Read raw traces
  df_sample <- read_hplc_agilent(sample_d_path,
                                 signal_wavelength = signal_wavelength,
                                 signal_ref        = signal_ref)

  # 280 nm is never blank subtracted, whatever the caller asked for.
  # Why: measured over 69 production runs, the gradient baseline drifts
  # 1.81 mAU/min at 214 nm but only 0.003 mAU/min at 280 nm, and the blank
  # accounts for under 0.04 percent of any 280 nm peak area (up to 1.5 percent
  # at 214 nm). There is simply nothing at 280 nm for a blank subtraction to
  # remove, and it does harm: against hand integrated areas on 8 well resolved
  # peaks the hybrid path is biased high on every peak (median +6.6 percent, up
  # to +12.2 percent) while ALS alone stays within +/- 2.6 percent. The hybrid
  # path also crashed inside baseline_hybrid_sm on 1 of 57 runs at 280 nm and
  # rescued no real quantitation there (its apparent rescues are all runs with
  # no 280 nm chromophore, which return NA anyway).
  # Why this overrides an explicit use_hybrid = TRUE rather than only changing
  # the default: the Shiny app sets use_hybrid from "a blank folder was found",
  # which is a fact about the plate layout and not a scientific judgement, so a
  # default-only change would leave every app run blank subtracting at 280 nm.
  use_hybrid_baseline <- use_hybrid && signal_wavelength != 280

  if (use_hybrid_baseline && !is.null(blank_d_path)) {
    df_blank <- read_hplc_agilent(blank_d_path,
                                  signal_wavelength = signal_wavelength,
                                  signal_ref        = signal_ref)
  }

  # 2) Baseline correction
  # 2) Baseline correction
  if (!use_hybrid_baseline) {
    df_hybrid <- baseline_als(
      df_sample,
      lambda    = sample_als_lambda,
      p         = sample_als_p,
      show_plot = show_intermediate_plots
    )
  } else {
    # NEW: align→subtract-after-injector→hybrid
    ah <- align_subtract_then_hybrid(
      df_sample = df_sample,
      df_blank  = df_blank,
      # pass through your hybrid knobs
      pre_win       = pre_win,
      pre_p         = pre_p,
      noise_factor  = noise_factor,
      min_peak_dist = min_peak_dist,
      min_seg_len   = min_seg_len,
      als_lambda    = hybrid_als_lambda,
      als_p         = hybrid_als_p,
      show_plots    = show_intermediate_plots
      # (you can also pass bridge_* here if you want different defaults)
    )
    df_hybrid <- ah$df_hybrid
  }


  # Set injection volume: use file-detected value or parameter override
  file_inj_vol <- attr(df_sample, "inj_vol_ml")
  attr(df_hybrid, "inj_vol_ml") <- if (is.na(inj_vol_ml)) {
    # Auto-detect from file, or use 0.1 mL default if not found
    if (!is.null(file_inj_vol)) file_inj_vol else 0.1
  } else {
    # Use parameter (user override)
    inj_vol_ml
  }


  # 3) Optional baseline summary plot
  if (show_intermediate_plots) {
    library(ggplot2)
    plt <- ggplot(df_hybrid, aes(
      time,
      y = corrected
    )) +
      geom_line() +
      labs(
        title = if (use_hybrid_baseline) "Hybrid Baseline" else "ALS Baseline",
        x = "Time (min)", y = "Corrected Absorbance (mAU)"
      ) +
      theme_minimal()
    print(plt)
  }

  # 4) Peak detection
  peak_table <- detect_peaks_on_smoothed(
    df_hybrid,
    post_win, post_p,
    snr,    min_peak_dist_detect, min_rt_frac, max_rt_frac
  )
  if (nrow(peak_table) == 0) {
    warning("No peaks detected in: ", sample_d_path)
    empty_plot <- ggplot() +
      labs(title = basename(sample_d_path),
           subtitle = "No peaks detected") +
      theme_minimal()
    return(list(
      df_hybrid        = df_hybrid,
      peak_table       = peak_table,
      epsilon          = NA_real_,
      concentration_uM = NA_real_,
      plot             = empty_plot
    ))
  }

  # 4b) Integrate against each peak's own endpoint baseline rather than against zero after a
  # global subtraction. The raw column is used on purpose: the chord is the baseline, so the
  # corrected column would have a baseline taken off twice. See
  # integrate_peak_against_endpoint_baseline() for what the global baseline was costing.
  reintegrated <- reintegrate_peaks_against_endpoint_baseline(
    peak_table, df_hybrid$time, least_corrected_trace(df_hybrid)
  )
  peak_table <- reintegrated$peak_table
  peak_geometry <- reintegrated$geometry

  # 5) Compute ε (formula depends on detection wavelength) and concentration
  inj_ml_use <- attr(df_hybrid, "inj_vol_ml")
  if (is.null(inj_ml_use)) inj_ml_use <- inj_vol_ml
  eps <- if (signal_wavelength == 280) {
    estimate_epsilon_280(peptide_sequence)
  } else {
    estimate_epsilon_214(peptide_sequence)
  }
  largest <- peak_table %>% slice_max(height, n = 1)

  conc    <- calculate_peak_conc(
    largest$area, eps,
    inj_vol_ml   = inj_ml_use,
    flow_rate_ml = flow_rate_ml,
    pathlength_cm= pathlength_cm
  )


  # 6) Final annotated peak plot
  peak_plot <- plot_largest_peak(
    df_hybrid, peak_table,
    basename(sample_d_path),
    if (use_hybrid_baseline) basename(blank_d_path) else NULL,
    epsilon = eps,
    conc_uM  = conc$c_uM,
    signal_wavelength = signal_wavelength,
    peak_geometry = peak_geometry
  )

  # 7) Return results
  list(
    peak_geometry    = peak_geometry,
    df_hybrid        = df_hybrid,
    peak_table       = peak_table,
    epsilon          = eps,
    concentration_uM = conc$c_uM,
    plot             = peak_plot
  )
}
