#' Global ALS baseline correction (with optional plot)
#'
#' Applies Asymmetric Least Squares to subtract a smooth baseline
#' from a raw HPLC trace, and optionally displays the result.
#'
#' @param df A data.frame with columns **time**, **intensity**.
#' @param lambda Numeric. ALS λ smoothing parameter. Default 4.5.
#' @param p      Numeric. ALS asymmetry parameter.       Default 1e-4.
#' @param show_plot Logical. If TRUE, prints a diagnostic ggplot. Default FALSE.
#' @return The input `df` augmented with:
#'   - **baseline**  : the fitted baseline
#'   - **corrected** : intensity − baseline
#' @export
baseline_als <- function(df,
                         lambda    = 4.5,
                         p         = 1e-4,
                         show_plot = TRUE) {
  bl <- baseline(matrix(df$intensity, 1),
                 method = "als",
                 lambda = lambda,
                 p      = p)

  df2 <- df %>%
    mutate(
      baseline  = getBaseline(bl)[1, ],
      corrected = getCorrected(bl)[1, ]
    )

  if (show_plot) {
    library(ggplot2)
    p <- ggplot(df2, aes(time)) +
      geom_line(aes(y = intensity), color = "gray70", alpha = 0.7) +
      geom_line(aes(y = baseline),  color = "blue",    linetype="dashed") +
      geom_line(aes(y = corrected), color = "black") +
      labs(title = "ALS Baseline Correction",
           x = "Time (min)", y = "Absorbance (mAU)") +
      theme_minimal()
    print(p)
  }

  df2
}
