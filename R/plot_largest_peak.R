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
#' @param peak_geometry List from `integrate_peak_against_endpoint_baseline()`, or NULL. When
#'   given, the plot draws the baseline the area was actually measured against: the chord
#'   between the peak's two feet, the region counted above it, and a dropped line at each
#'   valley where a fused neighbour was cut away. Showing a shaded area against a baseline the
#'   viewer cannot see is how the previous integration went unquestioned for so long.
#' @return A ggplot object.
#' @export
plot_largest_peak <- function(df_hybrid, peak_table,
                              sample_name, blank_name = NULL,
                              epsilon, conc_uM, signal_wavelength,
                              peak_geometry = NULL) {
  largest  <- peak_table %>% slice_max(height, n = 1)
  rt       <- largest$apex_rt; start_rt <- largest$start_rt
  end_rt   <- largest$end_rt; height   <- largest$height
  area     <- largest$area
  drawn_on_raw <- !is.null(peak_geometry)
  if (drawn_on_raw) {
    start_rt <- peak_geometry$start_rt
    end_rt   <- peak_geometry$end_rt
  }
  i_start  <- which.min(abs(df_hybrid$time - start_rt))
  i_end    <- which.min(abs(df_hybrid$time - end_rt))
  df_peak  <- df_hybrid[i_start:i_end, ]
  df_hybrid$plotted <- if (drawn_on_raw) least_corrected_trace(df_hybrid) else df_hybrid$corrected
  df_peak$plotted   <- if (drawn_on_raw) least_corrected_trace(df_peak)   else df_peak$corrected
  if (drawn_on_raw) {
    chord_at <- function(x) peak_geometry$foot_start_level +
      (peak_geometry$foot_end_level - peak_geometry$foot_start_level) *
      (x - peak_geometry$foot_start_rt) /
      (peak_geometry$foot_end_rt - peak_geometry$foot_start_rt)
    df_peak$floor <- chord_at(df_peak$time)
    df_chord <- data.frame(time = c(peak_geometry$foot_start_rt, peak_geometry$foot_end_rt),
                           level = c(peak_geometry$foot_start_level, peak_geometry$foot_end_level))
  } else {
    df_peak$floor <- 0
    df_chord <- NULL
  }

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
  xr   <- range(df_hybrid$time); yr <- range(df_hybrid$plotted)
  xmin <- xr[1] + 0.60*diff(xr); xmax <- xr[1] + 0.98*diff(xr)
  ymin <- yr[1] + 0.55*diff(yr); ymax <- yr[1] + 0.98*diff(yr)
  title_txt <- if (is.null(blank_name)) {
    paste0("Largest Peak in ", sample_name)
  } else {
    paste0("Largest Peak in ", sample_name, " (vs ", blank_name, ")")
  }

  y_label <- if (drawn_on_raw) "Absorbance (mAU)" else "Corrected Absorbance (mAU)"
  plt <- ggplot(df_hybrid, aes(time, plotted)) +
    geom_ribbon(data = df_peak, aes(x = time, ymin = floor, ymax = pmax(plotted, floor)),
                fill = "#2a78d6", alpha = 0.30, inherit.aes = FALSE) +
    geom_line()
  if (drawn_on_raw) {
    plt <- plt +
      geom_vline(xintercept = peak_geometry$drop_rts, colour = "#eb6834",
                 linetype = "dotted", linewidth = 0.5) +
      geom_line(data = df_chord, aes(time, level), colour = "#eb6834",
                linewidth = 1, inherit.aes = FALSE) +
      geom_point(data = df_chord, aes(time, level), colour = "#eb6834",
                 size = 1.8, inherit.aes = FALSE)
  }
  plt +
    geom_vline(xintercept = rt, linetype="dashed") +
    annotate("text", x=rt, y=height,
             label = paste0("RT=",sprintf("%.2f",rt)," min\n",
                            "H=",sprintf("%.1f",height)," mAU\n",
                            "A=",sprintf("%.2f",area)," mAU·min"),
             hjust=0.5, vjust=-1.2, size=4) +
    labs(title=title_txt, x="Time (min)", y=y_label) +
    theme_minimal() +
    annotation_custom(tbl, xmin, xmax, ymin, ymax)
}
