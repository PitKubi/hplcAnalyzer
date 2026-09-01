#' The baseline column that pairs with `least_corrected_trace()`
#'
#' The two processing paths name their columns differently but the pairing is fixed: the plain
#' ALS path fits `baseline` to `intensity`, the blank-subtracting path fits `baseline_local` to
#' `raw_diff`. A baseline is only interpretable against the trace it was fitted to, so anything
#' that draws or measures one has to pick the matching pair rather than reach for whichever
#' column happens to be present.
#'
#' @param df Data.frame from the analysis pipeline.
#' @return Numeric vector, or NULL if the frame carries no fitted baseline.
#' @export
baseline_fitted_to_least_corrected_trace <- function(df) {
  if (!is.null(df$intensity)) return(df$baseline)
  if (!is.null(df$raw_diff)) return(df$baseline_local)
  NULL
}

#' How far a fitted baseline rises above the trace it was fitted to
#'
#' A baseline that sits above its own raw signal is subtracting more than the signal contains,
#' which is the thing to watch for. Small excursions are normal where the fit smooths through
#' noise; a sustained rise over a peak is not.
#'
#' @param trace Numeric vector, the trace the baseline was fitted to.
#' @param baseline Numeric vector, the fitted baseline.
#' @return List with `fraction_of_points` and `largest_excess`.
#' @export
summarise_baseline_above_trace <- function(trace, baseline) {
  excess <- baseline - trace
  list(fraction_of_points = mean(excess > 0, na.rm = TRUE),
       largest_excess     = max(c(excess, 0), na.rm = TRUE))
}

BASELINE_PANEL_BEFORE <- "Raw signal, with the fitted baseline"
BASELINE_PANEL_AFTER  <- "After subtraction"

#' Plot a baseline against the trace it was fitted to, and the result of subtracting it
#'
#' Two stacked panels sharing a time axis: above, the raw signal with the fitted baseline drawn
#' on it; below, what is left after subtraction. The subtitle reports how much of the raw trace
#' the baseline rises above.
#'
#' The panels are deliberately not superimposed. Drawing the baseline in the same axes as the
#' *corrected* trace is what the app did until 0.7.7, and it is misleading: the corrected trace
#' sits near zero while the baseline sits at whatever it is subtracting, so the baseline appears
#' to tower over the signal on most of the run. That comparison is meaningless, because a
#' baseline is above the signal it has already been subtracted from by exactly the amount it
#' subtracted. The only comparison that says whether a baseline is cutting into a peak is against
#' the raw trace, so that is the one drawn here, in its own panel.
#'
#' @param df Data.frame from the analysis pipeline, carrying a raw trace, its fitted baseline
#'   and `corrected`.
#' @return A ggplot object, or NULL if the frame carries no fitted baseline.
#' @export
plot_baseline_subtraction <- function(df) {
  baseline <- baseline_fitted_to_least_corrected_trace(df)
  if (is.null(baseline)) return(NULL)
  raw <- least_corrected_trace(df)

  panels <- factor(c(BASELINE_PANEL_BEFORE, BASELINE_PANEL_AFTER),
                   levels = c(BASELINE_PANEL_BEFORE, BASELINE_PANEL_AFTER))
  traces <- rbind(
    data.frame(time = df$time, value = raw,           panel = panels[1], series = "Raw signal"),
    data.frame(time = df$time, value = baseline,      panel = panels[1], series = "Fitted baseline"),
    data.frame(time = df$time, value = df$corrected,  panel = panels[2], series = "Corrected")
  )
  traces$series <- factor(traces$series, levels = c("Raw signal", "Fitted baseline", "Corrected"))

  above <- summarise_baseline_above_trace(raw, baseline)
  subtitle <- sprintf(
    "The baseline rises above the raw trace on %.1f%% of points, by at most %.2f mAU. Areas are not taken from this pass; it seeds peak detection.",
    100 * above$fraction_of_points, above$largest_excess)

  ggplot2::ggplot(traces, ggplot2::aes(time, value,
                                       colour = series, linetype = series)) +
    ggplot2::geom_hline(data = data.frame(panel = panels[2]),
                        ggplot2::aes(yintercept = 0), colour = "gray80", inherit.aes = FALSE) +
    ggplot2::geom_line(linewidth = 0.4) +
    ggplot2::facet_wrap(~panel, ncol = 1, scales = "free_y") +
    ggplot2::scale_colour_manual(values = c("Raw signal" = "gray45",
                                            "Fitted baseline" = "#2c6fbb",
                                            "Corrected" = "black")) +
    ggplot2::scale_linetype_manual(values = c("Raw signal" = "solid",
                                              "Fitted baseline" = "dashed",
                                              "Corrected" = "solid")) +
    ggplot2::labs(title = "Baseline subtraction", subtitle = subtitle,
                  x = "Time (min)", y = "Absorbance (mAU)",
                  colour = NULL, linetype = NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "bottom",
                   plot.subtitle = ggplot2::element_text(size = 9, colour = "gray30"))
}
