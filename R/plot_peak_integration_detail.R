#' Zoomed view of what was integrated and the baseline it was measured against
#'
#' A companion to [plot_largest_peak()], which always shows the whole acquired chromatogram and
#' must keep doing so. At full-run scale the chord and the shaded area are a few pixels tall, so
#' the one thing a reviewer needs to check, whether the baseline passes under the peak, is not
#' visible. This draws the same geometry over a window around the peak. The full trace is not
#' replaced by it; both are shown.
#'
#' @param df_hybrid Data.frame with `time` and `intensity`.
#' @param peak_geometry List from [integrate_peak_against_endpoint_baseline()].
#' @param area Numeric. The integrated area, for the caption.
#' @param margin_min Numeric. Minutes of trace to keep either side. Default 1.2.
#' @return A ggplot, or NULL when there is no geometry to draw.
#' @export
plot_peak_integration_detail <- function(df_hybrid, peak_geometry, area = NA_real_,
                                         margin_min = 1.2) {
  if (is.null(peak_geometry) || !is.finite(peak_geometry$foot_start_rt)) return(NULL)

  chord_at <- function(x) peak_geometry$foot_start_level +
    (peak_geometry$foot_end_level - peak_geometry$foot_start_level) *
    (x - peak_geometry$foot_start_rt) /
    (peak_geometry$foot_end_rt - peak_geometry$foot_start_rt)

  window <- df_hybrid[df_hybrid$time > peak_geometry$foot_start_rt - margin_min &
                      df_hybrid$time < peak_geometry$foot_end_rt + margin_min, ]
  counted <- df_hybrid[df_hybrid$time >= peak_geometry$start_rt &
                       df_hybrid$time <= peak_geometry$end_rt, ]
  counted$floor <- chord_at(counted$time)
  chord <- data.frame(time = c(peak_geometry$foot_start_rt, peak_geometry$foot_end_rt),
                      level = c(peak_geometry$foot_start_level, peak_geometry$foot_end_level))

  subtitle <- if (is.finite(area)) {
    sprintf("area %.2f mAU·min, measured above the orange chord between the peak's own two feet", area)
  } else {
    "measured above the orange chord between the peak's own two feet"
  }

  ggplot(window, aes(time, intensity)) +
    geom_ribbon(data = counted, aes(x = time, ymin = floor, ymax = pmax(intensity, floor)),
                fill = "#2a78d6", alpha = 0.30, inherit.aes = FALSE) +
    geom_line(linewidth = 0.5) +
    geom_vline(xintercept = peak_geometry$drop_rts, colour = "#eb6834",
               linetype = "dotted", linewidth = 0.6) +
    geom_line(data = chord, aes(time, level), colour = "#eb6834", linewidth = 1.1,
              inherit.aes = FALSE) +
    geom_point(data = chord, aes(time, level), colour = "#eb6834", size = 2.4,
               inherit.aes = FALSE) +
    labs(title = "Integration detail", subtitle = subtitle,
         x = "Time (min)", y = "Absorbance (mAU)") +
    theme_minimal()
}
