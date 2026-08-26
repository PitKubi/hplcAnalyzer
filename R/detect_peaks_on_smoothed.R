#' Detect peaks on Savitzky–Golay–smoothed trace (with RT cutoff)
#'
#' @param df Data.frame with columns **time** and **corrected**.
#' @param post_win Integer. SG window for final smoothing. Default 11.
#' @param post_p   Integer. SG polynomial order. Default 3.
#' @param snr Numeric. Signal-to-noise ratio threshold. Default 5.
#' @param min_peak_dist Integer. Min distance between peaks (points). Default 10.
#' @param min_rt_frac Numeric. Fraction (0–1) of total run time; peaks earlier than this are dropped. Default 0.3.
#' @param max_rt_frac Numeric. Fraction (0–1) of total run time; peaks later than this are dropped. Default 1, which keeps the whole run.
#' @return A tibble of peaks with columns peak, height, apex_rt, start_rt, end_rt, area.
#' @export
detect_peaks_on_smoothed <- function(df,
                                     post_win      = 11,
                                     post_p        = 3,
                                     snr           = 5,
                                     min_peak_dist = 10,
                                     min_rt_frac   = 0.3,
                                     max_rt_frac   = 1) {
  # 1) SG‐smooth
  df <- df %>%
    mutate(sg_smoothed = sgolayfilt(corrected, p = post_p, n = post_win))

  # 2) Noise estimate
  sd_noise <- sd(df$sg_smoothed[1:50], na.rm = TRUE)

  # 3) Raw peak finding
  peaks_raw <- findpeaks(
    df$sg_smoothed,
    minpeakheight   = snr * sd_noise,
    minpeakdistance = min_peak_dist
  )
  if (is.null(peaks_raw)) {
    return(tibble(
      peak      = integer(),
      height    = double(),
      apex_rt   = double(),
      start_rt  = double(),
      end_rt    = double(),
      area      = double()
    ))
  }

  # 4) Build peaks tibble
  peaks <- tibble(
    peak     = seq_len(nrow(peaks_raw)),
    height   = peaks_raw[, 1],
    apex_rt  = df$time[peaks_raw[, 2]],
    start_rt = df$time[peaks_raw[, 3]],
    end_rt   = df$time[peaks_raw[, 4]]
  )

  # 5) Compute each peak’s area with
  peaks <- peaks %>%
    rowwise() %>%
    mutate(
      area = pracma::trapz(
        df$time[peaks_raw[peak, 3]:peaks_raw[peak, 4]],
        df$sg_smoothed[peaks_raw[peak, 3]:peaks_raw[peak, 4]]
      )
    ) %>%
    ungroup()

  # 6) RT window
  # Both bounds are fractions of the run rather than minutes so that one setting travels
  # across methods of different length; a single production batch already mixes 20.0 and
  # 24.1 minute runs.
  # Why an upper bound exists at all: every method here ends with a column regeneration /
  # high organic step, and the detector reports that step as a peak like any other. Measured
  # across 66 runs of batch a 57 peptide production batch it apexes between 20.7 and 24.0
  # minutes on a 24.1 minute run while no genuine analyte peak elutes later than 18.0
  # minutes, so it is instrument behaviour and not sample.
  # Why the default is 1 and not a value that would exclude it: apex_rt is always drawn from
  # df$time, so apex_rt <= 1 * total_time can never drop a row, and a caller that does not
  # set this bound gets exactly the peak table it got before the bound existed. Changing the
  # default would silently move every reported purity number.
  total_time <- max(df$time, na.rm = TRUE)
  peaks %>%
    dplyr::filter(apex_rt >= min_rt_frac * total_time,
                  apex_rt <= max_rt_frac * total_time)
}
