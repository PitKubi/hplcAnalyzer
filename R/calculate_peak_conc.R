#' Calculate concentration from peak area
#'
#' @param area Numeric. Peak area (mAU·min).
#' @param epsilon Numeric. Extinction coefficient (M⁻¹·cm⁻¹).
#' @param inj_vol_ml Numeric. Injection volume (mL). Default 0.1.
#' @param flow_rate_ml Numeric. Flow rate (mL/min). Default 1.
#' @param pathlength_cm Numeric. Cell pathlength (cm). Default 1.
#' @return A list with \code{c_M} (M) and \code{c_uM} (μM).
#' @export
calculate_peak_conc <- function(area,
                                epsilon,
                                inj_vol_ml   = 0.1,
                                flow_rate_ml = 1,
                                pathlength_cm= 1) {
  abs_mL <- area * flow_rate_ml / 1000
  c_M    <- abs_mL / (epsilon * pathlength_cm * inj_vol_ml)
  c_uM   <- c_M * 1e6
  list(c_M = c_M, c_uM = c_uM)
}
