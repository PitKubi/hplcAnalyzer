#' Hybrid ALS + piecewise baseline correction (with optional plot)
#'
#' @param df_sample Data.frame from baseline_als().
#' @param df_blank  Data.frame from baseline_als() on blank.
#' @param pre_win,pre_p,noise_factor,min_peak_dist,min_seg_len Hybrid params.
#' @param als_lambda,als_p ALS params for the piecewise step.
#' @param show_plot Logical. If TRUE, prints corrected trace. Default FALSE.
#' @return df_sample with raw_diff, smooth_diff, baseline_local, corrected_hybrid.
#' @export
baseline_hybrid_sm <- function(df_sample, df_blank,
                               pre_win          = 7,
                               pre_p            = 2,
                               noise_factor     = 0.1,
                               min_peak_dist    = 1,
                               min_seg_len      = 20,
                               als_lambda       = 1,
                               als_p            = 1e-4,
                               show_plot        = FALSE) {
  blank_i  <- approx(df_blank$time, df_blank$intensity,
                     xout = df_sample$time, rule = 2)$y
  raw_diff <- df_sample$intensity - blank_i

  smooth_diff <- sgolayfilt(raw_diff, p=pre_p, n=pre_win)

  inv      <- -smooth_diff
  sd_noise <- sd(smooth_diff[1:50])
  mins     <- findpeaks(inv,
                        minpeakheight   = noise_factor * sd_noise,
                        minpeakdistance = min_peak_dist)
  nodes <- if (is.null(mins)) c(1, length(smooth_diff)) else
    sort(unique(c(1, mins[,2], length(smooth_diff))))
  seg_lens <- diff(nodes)
  keep     <- which(seg_lens >= min_seg_len)
  idx_nodes<- sort(unique(c(nodes[keep], nodes[keep+1])))

  baseline_local <- numeric(length(raw_diff))
  for (i in seq_along(idx_nodes)[-length(idx_nodes)]) {
    seg <- idx_nodes[i]:idx_nodes[i+1]
    bl  <- baseline(matrix(raw_diff[seg],1),
                    method="als",
                    lambda=als_lambda,
                    p=als_p)
    baseline_local[seg] <- getBaseline(bl)[1,]
  }

  df2 <- df_sample %>%
    mutate(
      raw_diff         = raw_diff,
      smooth_diff      = smooth_diff,
      baseline_local   = baseline_local,
      corrected = raw_diff - baseline_local
    )

  if (show_plot) {
    library(ggplot2)
    p <- ggplot(df2, aes(time)) +
      geom_line(aes(y = raw_diff),        color = "gray70") +
      geom_line(aes(y = baseline_local),  color = "blue",    linetype = "dashed") +
      geom_line(aes(y = corrected),color = "black") +
      labs(title = "Hybrid Baseline Correction",
           x = "Time (min)", y = "Absorbance (mAU)") +
      theme_minimal()
    print(p)
  }

  df2
}
