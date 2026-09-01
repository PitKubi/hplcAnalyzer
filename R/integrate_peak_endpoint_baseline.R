# Integration of a peak against a baseline drawn between its own two feet.
#
# The alternative, and what this package did before, is to subtract a global baseline from the
# whole trace and then integrate against zero. That fails in a specific way: an ALS baseline
# fitted to the whole chromatogram rises under a peak instead of passing beneath it, and the
# area under that hump is lost. Measured over 47 runs of a production batch it costs a median
# 9.6 percent of the 214 nm peak area, about 2 percent on a well-resolved peak and 10 to 12 on
# a crowded one, worst case 52 percent.
#
# So the baseline is drawn locally instead: a straight chord between the levels fitted at the
# peak's own two feet, with only signal above that chord counted. The approach is the one used
# in Peter Kubiniok's Prism integration code and is standard chromatographic practice.
#
# Two rules make it behave on real traces. The walk outward from the apex does not stop at the
# first dip, because a dip that is still well above the local level is a fused neighbour rather
# than the end of the peak; it keeps going and remembers where the dip was. And each remembered
# dip becomes a perpendicular drop, so only the slice holding the tallest apex, the analyte, is
# integrated.

# How close to the local level the trace has to come before the walk calls it the foot. Set by
# sweeping it on six peaks and watching where the integrated area stops moving. At 0.02 the walk
# stopped well up the flank: on one peak it put the chord at 44 mAU where the trace either side
# of the peak sits at 32, so 13 mAU of signal was cut off across the peak's whole width. Areas
# stop changing by 0.002, and below that nothing moves by more than 0.15 percent in total while
# the chord settles within about 2 mAU of the local baseline.
FOOT_FRACTION_OF_APEX_HEIGHT <- 0.002
MIN_POINTS_BETWEEN_VALLEY_AND_APEX <- 6
MIN_VALLEY_PROMINENCE_FRACTION <- 0.03

#' Level of the local baseline at one edge of a peak
#'
#' Fits a low order polynomial to the points nearest the edge, taken from the side away from
#' the apex so the fit never leans on the peak itself, and evaluates it at the edge.
#'
#' @param time,signal Numeric vectors of the trace.
#' @param edge_time Numeric. Where the level is wanted.
#' @param apex_time Numeric. Used only to decide which side is the outer one.
#' @param n_points Integer. How many neighbouring points the fit uses. Default 10.
#' @return Numeric. The fitted level at `edge_time`.
#' @export
fit_baseline_level_at_edge <- function(time, signal, edge_time, apex_time, n_points = 10) {
  interpolated <- function() as.numeric(stats::approx(time, signal, edge_time, rule = 2)$y)
  outer_side <- if (edge_time <= apex_time) time <= apex_time else time >= apex_time
  if (!any(outer_side)) return(interpolated())
  outer_time <- time[outer_side]; outer_signal <- signal[outer_side]
  nearest <- order(abs(outer_time - edge_time))[seq_len(min(n_points, length(outer_time)))]
  xs <- outer_time[nearest]; ys <- outer_signal[nearest]
  if (length(xs) < 3) return(interpolated())
  degree <- if (length(xs) >= 5) 2 else 1
  fit <- try(stats::lm(ys ~ stats::poly(xs, degree, raw = TRUE)), silent = TRUE)
  if (inherits(fit, "try-error")) return(interpolated())
  unname(stats::predict(fit, data.frame(xs = edge_time)))
}

walk_from_apex_to_foot <- function(signal, apex_index, step, apex_height, local_level,
                                   stop_index = NA_integer_,
                                   foot_fraction = FOOT_FRACTION_OF_APEX_HEIGHT) {
  foot_level <- local_level + foot_fraction * (apex_height - local_level)
  prominence <- MIN_VALLEY_PROMINENCE_FRACTION * (apex_height - local_level)
  last_index <- length(signal)
  index <- apex_index
  valleys <- integer(0)
  repeat {
    next_index <- index + step
    if (next_index < 2 || next_index > last_index - 1) break
    if (!is.na(stop_index) && ((step < 0 && next_index <= stop_index) ||
                               (step > 0 && next_index >= stop_index))) break
    if (signal[next_index] > signal[index]) {
      if (signal[index] <= foot_level) break
      over_rider <- next_index
      rider_top <- signal[over_rider]
      while (over_rider >= 2 && over_rider <= last_index - 1 &&
             signal[over_rider] >= signal[over_rider - step]) {
        rider_top <- max(rider_top, signal[over_rider])
        over_rider <- over_rider + step
      }
      is_real_valley <- abs(index - apex_index) >= MIN_POINTS_BETWEEN_VALLEY_AND_APEX &&
        (rider_top - signal[index]) >= prominence
      if (is_real_valley) valleys <- c(valleys, index)
      if (over_rider < 2 || over_rider > last_index - 1) break
      next_index <- over_rider
    }
    index <- next_index
    if (signal[index] <= foot_level) break
  }
  list(foot = index, valleys = valleys)
}

#' Integrate a peak against a baseline drawn between its own two feet
#'
#' @param time,signal Numeric vectors of the trace. Give it the **raw** trace: the chord is the
#'   baseline, so a globally corrected trace would have its baseline removed twice.
#' @param apex_time Numeric. Retention time of the peak to integrate.
#' @param n_points Integer. Points used to fit each foot level. Default 10.
#' @param foot_fraction Numeric. How close to the local level the trace has to come before the
#'   walk calls it the foot, as a fraction of peak height above that level. Set by sweeping it
#'   until the integrated area stops changing; see the default's comment.
#' @param neighbour_apex_times Numeric. Apexes of the other detected peaks. The envelope stops
#'   at the valley between this peak and the nearest one on each side, so two peaks can never
#'   claim the same stretch of trace and the areas stay comparable to each other, which is what
#'   Area (%) depends on.
#' @return A list with `area`, the two feet `foot_start_rt`/`foot_end_rt` and their fitted
#'   levels `foot_start_level`/`foot_end_level`, the integrated span `start_rt`/`end_rt`, and
#'   `drop_rts`, the retention times of the perpendicular drops. `area` is `NA_real_` when the
#'   peak has no usable envelope.
#' @export
integrate_peak_against_endpoint_baseline <- function(time, signal, apex_time, n_points = 10,
                                                     neighbour_apex_times = numeric(0),
                                                     foot_fraction = FOOT_FRACTION_OF_APEX_HEIGHT) {
  empty <- list(area = NA_real_, foot_start_rt = NA_real_, foot_end_rt = NA_real_,
                foot_start_level = NA_real_, foot_end_level = NA_real_,
                start_rt = NA_real_, end_rt = NA_real_, drop_rts = numeric(0))
  if (length(time) < 10 || !is.finite(apex_time)) return(empty)
  apex_index <- which.min(abs(time - apex_time))
  apex_height <- signal[apex_index]
  local_level <- stats::median(signal, na.rm = TRUE)
  if (!is.finite(apex_height) || apex_height <= local_level) return(empty)

  neighbours <- neighbour_apex_times[is.finite(neighbour_apex_times)]
  before <- neighbours[neighbours < apex_time]
  after  <- neighbours[neighbours > apex_time]
  # The shared boundary between two peaks is the valley between them, not the neighbour's apex.
  # Stopping at the apex would cut the near side of this peak off at its own shoulder.
  valley_between <- function(other_apex_time) {
    span <- sort(c(which.min(abs(time - other_apex_time)), apex_index))
    span[1] + which.min(signal[span[1]:span[2]]) - 1L
  }
  stop_left  <- if (length(before)) valley_between(max(before)) else NA_integer_
  stop_right <- if (length(after))  valley_between(min(after))  else NA_integer_

  left <- walk_from_apex_to_foot(signal, apex_index, -1L, apex_height, local_level, stop_left, foot_fraction)
  right <- walk_from_apex_to_foot(signal, apex_index, +1L, apex_height, local_level, stop_right, foot_fraction)
  if (right$foot - left$foot < 5) return(empty)

  foot_start_rt <- time[left$foot]; foot_end_rt <- time[right$foot]
  start_level <- fit_baseline_level_at_edge(time, signal, foot_start_rt, apex_time, n_points)
  end_level   <- fit_baseline_level_at_edge(time, signal, foot_end_rt,   apex_time, n_points)
  chord_at <- function(x) start_level + (end_level - start_level) *
    (x - foot_start_rt) / (foot_end_rt - foot_start_rt)

  drops <- sort(c(left$valleys, right$valleys))
  drops <- drops[signal[drops] > chord_at(time[drops])]
  bounds <- sort(unique(c(left$foot, drops, right$foot)))
  tallest <- which.max(vapply(seq_len(length(bounds) - 1),
                              function(k) max(signal[bounds[k]:bounds[k + 1]]), numeric(1)))
  inside <- bounds[tallest]:bounds[tallest + 1]

  list(area = pracma::trapz(time[inside], pmax(signal[inside] - chord_at(time[inside]), 0)),
       foot_start_rt = foot_start_rt, foot_end_rt = foot_end_rt,
       foot_start_level = start_level, foot_end_level = end_level,
       start_rt = time[bounds[tallest]], end_rt = time[bounds[tallest + 1]],
       drop_rts = time[drops])
}

#' Re-integrate every detected peak against its own endpoint baseline
#'
#' Replaces the `area` column produced by `detect_peaks_on_smoothed()`, and returns the
#' geometry of the tallest peak so the plot can draw the same baseline it integrated against.
#' A peak whose envelope cannot be walked keeps the area it already had, so a run never
#' silently loses a number.
#'
#' @param peak_table Tibble from `detect_peaks_on_smoothed()`.
#' @param time,signal The raw trace to integrate.
#' @return A list with the updated `peak_table` and the `geometry` of the tallest peak.
#' @export
reintegrate_peaks_against_endpoint_baseline <- function(peak_table, time, signal) {
  if (nrow(peak_table) == 0) return(list(peak_table = peak_table, geometry = NULL))
  integrations <- lapply(peak_table$apex_rt, function(apex)
    integrate_peak_against_endpoint_baseline(
      time, signal, apex,
      neighbour_apex_times = peak_table$apex_rt[peak_table$apex_rt != apex]))
  areas <- vapply(integrations, function(x) x$area, numeric(1))
  peak_table$area <- ifelse(is.na(areas), peak_table$area, areas)
  tallest <- which.max(peak_table$height)
  geometry <- integrations[[tallest]]
  list(peak_table = peak_table,
       geometry = if (is.na(geometry$area)) NULL else geometry)
}
