#' Plot & annotate the largest peak with metrics
#'
#' @param df_hybrid Data.frame with corrected & time.
#' @param peak_table Tibble from \code{detect_peaks_on_smoothed()}.
#' @param sample_name Character. Name for plot title.
#' @param blank_name  Character or NULL.
#' @param epsilon    Numeric. Extinction coefficient (M⁻¹·cm⁻¹).
#' @param conc_uM    Numeric. Concentration (μM).
#' @param signal_wavelength Numeric. Detection wavelength in nm, used to label the
#'   ε row of the metrics table. Required, because a wrong ε label silently
#'   misattributes an Edelhoch ε280 to the Kuipers & Gruppen ε214 formula.
#' @return A ggplot object.
#' @export
plot_largest_peak <- function(df_hybrid, peak_table,
                              sample_name, blank_name = NULL,
                              epsilon, conc_uM, signal_wavelength) {
  largest  <- peak_table %>% slice_max(height, n = 1)
  rt       <- largest$apex_rt; start_rt <- largest$start_rt
  end_rt   <- largest$end_rt; height   <- largest$height
  area     <- largest$area
  i_start  <- which.min(abs(df_hybrid$time - start_rt))
  i_end    <- which.min(abs(df_hybrid$time - end_rt))
  df_peak  <- df_hybrid[i_start:i_end, ]

  labels <- c("RT (min)", "Height (mAU)", "Area (mAU·min)",
              sprintf("ε%d (M⁻¹·cm⁻¹)", signal_wavelength), "Conc (μM)")
  values <- c(sprintf("%.2f", rt),
              sprintf("%.1f", height),
              sprintf("%.2f", area),
              sprintf("%.0f", epsilon),
              sprintf("%.1f", conc_uM))
  if (length(values) < length(labels)) {
    values <- c(values, rep(NA, length(labels)-length(values)))
  }
  metrics <- data.frame(Metric = labels, Value = values,
                        stringsAsFactors = FALSE)
  tbl <- tableGrob(metrics, rows = NULL,
                   theme = ttheme_minimal(base_size = 10))
  xr   <- range(df_hybrid$time); yr <- range(df_hybrid$corrected)
  xmin <- xr[1] + 0.60*diff(xr); xmax <- xr[1] + 0.98*diff(xr)
  ymin <- yr[1] + 0.55*diff(yr); ymax <- yr[1] + 0.98*diff(yr)
  title_txt <- if (is.null(blank_name)) {
    paste0("Largest Peak in ", sample_name)
  } else {
    paste0("Largest Peak in ", sample_name, " (vs ", blank_name, ")")
  }

  ggplot(df_hybrid, aes(time, corrected)) +
    geom_line() +
    geom_ribbon(data = df_peak,
                aes(x=time, ymin=0, ymax=corrected),
                alpha=0.4) +
    geom_vline(xintercept = rt, linetype="dashed") +
    annotate("text", x=rt, y=height,
             label = paste0("RT=",sprintf("%.2f",rt)," min\n",
                            "H=",sprintf("%.1f",height)," mAU\n",
                            "A=",sprintf("%.2f",area)," mAU·min"),
             hjust=0.5, vjust=-1.2, size=4) +
    labs(title=title_txt, x="Time (min)", y="Corrected Absorbance (mAU)") +
    theme_minimal() +
    annotation_custom(tbl, xmin, xmax, ymin, ymax)
}
