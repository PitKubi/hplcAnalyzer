#' Align to blank by injector, subtract after injector, then hybrid baseline
#'
#' Aligns blank to sample by injector midpoint, subtracts only after the
#' injector window, bridges compact negative peaks (including positive→negative
#' pairs) in the subtraction, then runs `baseline_hybrid_sm()` on the
#' post-injector suffix. A 1-minute post-injector guard ramps the ALS baseline
#' from 0 to avoid dips.
#'
#' @param df_sample,data.frame Sample trace with columns time,intensity.
#' @param df_blank,data.frame  Blank trace with columns time,intensity.
#' @param t_max,sg_n,sg_p,pad_min Injector finder & padding (min).
#' @param pre_win,pre_p,noise_factor,min_peak_dist,min_seg_len Hybrid params for `baseline_hybrid_sm`.
#' @param als_lambda,als_p ALS params for the piecewise step.
#' @param bridge_z_neg,bridge_z_pos MAD thresholds for negative/positive peaks.
#' @param bridge_pos_window Minutes to look back for a positive bump before a negative dip.
#' @param bridge_max_width,bridge_pad Width cap and padding for bridge segments (min).
#' @param tail_minutes,tail_relax Relax thresholds in the last minutes of the run.
#' @param show_plots Logical; diagnostic plot if TRUE.
#' @return list with `df_hybrid`, `shift_min`, `injector`.
#' @export
#' @importFrom stats approx mad sd runmed
#' @importFrom signal sgolayfilt
#' @importFrom pracma findpeaks
align_subtract_then_hybrid <- function(
    df_sample, df_blank,
    t_max = 5, sg_n = 21, sg_p = 2, pad_min = 0.20,
    pre_win = 7, pre_p = 2, noise_factor = 0.1,
    min_peak_dist = 1, min_seg_len = 20,
    als_lambda = 7.0, als_p = 5e-4,
    show_plots = FALSE,
    # simple knobs kept for compatibility
    bridge_max_width = 2.5, bridge_pad = 0.03,
    # NEW pair-aware/adaptive knobs
    bridge_pos_window = 0.8,
    bridge_z_neg      = 1.0,
    bridge_z_pos      = 1.2,
    tail_minutes      = 5.0,
    tail_relax        = 0.7
) {
  stopifnot(all(c("time","intensity") %in% names(df_sample)),
            all(c("time","intensity") %in% names(df_blank)))
  if (!exists("baseline_hybrid_sm"))
    stop("baseline_hybrid_sm() must be available in the package.")

  # ---- helpers: injector & alignment ----
  find_injector_peaks <- function(time, y, t_max, sg_n, sg_p, pad_min) {
    idx <- which(time <= t_max); if (length(idx) < 5) return(NULL)
    if (sg_n >= length(idx)) sg_n <- max(5, 2*floor((length(idx)-1)/2) + 1)
    y_sm <- signal::sgolayfilt(y[idx], p = sg_p, n = sg_n)
    i_min <- idx[which.min(y_sm)]; i_max <- idx[which.max(y_sm)]
    t_min <- time[i_min]; t_maxp <- time[i_max]
    t0 <- max(min(t_min, t_maxp) - pad_min, min(time))
    t1 <- min(max(t_min, t_maxp) + pad_min, max(time))
    list(i_min = i_min, t_min = t_min, i_max = i_max, t_max = t_maxp,
         t_start = t0, t_end = t1)
  }
  align_blank_by_injector <- function(time_s, y_s, time_b, y_b, t_max, sg_n, sg_p, pad_min) {
    s <- find_injector_peaks(time_s, y_s, t_max, sg_n, sg_p, pad_min)
    b <- find_injector_peaks(time_b, y_b, t_max, sg_n, sg_p, pad_min)
    if (is.null(s)) stop("Could not locate injector peaks in sample.")
    if (is.null(b)) stop("Could not locate injector peaks in blank.")
    mid_s <- (s$t_min + s$t_max)/2; mid_b <- (b$t_min + b$t_max)/2
    shift <- mid_s - mid_b
    y_ba  <- approx(time_b + shift, y_b, xout = time_s, rule = 2)$y
    list(y_b_aligned = y_ba, shift_min = shift, inj_sample = s, inj_blank = b)
  }

  # 1) align
  al   <- align_blank_by_injector(df_sample$time, df_sample$intensity,
                                  df_blank$time,  df_blank$intensity,
                                  t_max, sg_n, sg_p, pad_min)
  time <- df_sample$time; y_s <- df_sample$intensity; y_ba <- al$y_b_aligned
  inj_start <- al$inj_sample$t_start; inj_end <- al$inj_sample$t_end
  after_inj <- time >= inj_end; i0 <- which(after_inj)[1]

  # 2) subtract only after injector
  residual_true <- y_s
  residual_true[after_inj] <- y_s[after_inj] - y_ba[after_inj]
  blank_mask <- ifelse(after_inj, y_ba, 0)

  # --- pair-aware/adaptive bridging helper
  .bridge_posneg_adaptive <- function(
    time, y_s, y_b,
    z_neg = 1.0, z_pos = 1.2,
    pos_window_min = 0.8, max_width_min = 1.0, pad_min = 0.04,
    tail_minutes = 2.0, tail_relax = 0.6,
    detect_sg_min = 0.12, mad_win_min = 0.60
  ) {
    r   <- y_s - y_b
    dt  <- median(diff(time))
    nsg <- max(5L, 2L*floor((detect_sg_min/dt)/2) + 1L)
    rsm <- signal::sgolayfilt(r, p = 2, n = nsg)
    k_mad <- max(5L, 2L*floor((mad_win_min/dt)/2) + 1L)
    trend <- stats::runmed(rsm, k = k_mad, endrule = "median")
    resid <- abs(rsm - trend)
    mad_loc <- 1.4826 * stats::runmed(resid, k = k_mad, endrule = "median")
    mad_loc[!is.finite(mad_loc) | mad_loc <= 0] <- stats::sd(rsm, na.rm = TRUE)
    relax <- rep(1.0, length(time))
    tail_idx <- which(time >= max(time) - tail_minutes)
    if (length(tail_idx)) relax[tail_idx] <- tail_relax
    thr_neg <- z_neg * mad_loc * relax
    thr_pos <- z_pos * mad_loc * relax
    mindist <- max(1L, round(0.05/dt))
    pos_pk <- try(pracma::findpeaks( rsm, minpeakheight =  thr_pos, minpeakdistance = mindist), silent = TRUE)
    neg_pk <- try(pracma::findpeaks(-rsm, minpeakheight =  thr_neg, minpeakdistance = mindist), silent = TRUE)
    to_df <- function(pk, sgn=+1L){
      if (inherits(pk,"try-error") || is.null(pk) || !nrow(pk)) return(NULL)
      data.frame(height = sgn*pk[,1], idx = pk[,2], L = pk[,3], R = pk[,4])
    }
    P <- to_df(pos_pk, +1L)
    N <- to_df(neg_pk, -1L)
    segs <- list()
    pad_pts <- max(1L, round(pad_min/dt))
    max_len <- max(3L, round(max_width_min/dt))
    if (!is.null(N)) {
      for (i in seq_len(nrow(N))) {
        nL <- max(1,  N$L[i] - pad_pts); nR <- min(length(time), N$R[i] + pad_pts)
        if (!is.null(P)) {
          cnd <- which(time[P$idx] >= time[nL] - pos_window_min & time[P$idx] <= time[nL])
        } else cnd <- integer(0)
        if (length(cnd)) { j <- cnd[length(cnd)]; segL <- max(1, P$L[j] - pad_pts); segR <- nR
        } else { segL <- nL; segR <- nR }
        if ((segR - segL + 1) <= max_len) {
          r <- y_s - y_b
          line <- approx(time[c(segL, segR)], r[c(segL, segR)],
                         xout = time[segL:segR], rule = 2)$y
          y_b[segL:segR] <- y_s[segL:segR] - line
          segs[[length(segs)+1]] <- c(segL, segR)
        }
      }
    }
    list(yb = y_b, segs = segs)
  }

  # suffix only (post-injector)
  df_suf_s <- data.frame(time = time[i0:length(time)], intensity = y_s[i0:length(time)])
  df_suf_b <- data.frame(time = time[i0:length(time)], intensity = blank_mask[i0:length(time)])

  br <- .bridge_posneg_adaptive(
    time = df_suf_s$time, y_s = df_suf_s$intensity, y_b = df_suf_b$intensity,
    z_neg = bridge_z_neg, z_pos = bridge_z_pos,
    pos_window_min = bridge_pos_window,
    max_width_min  = max(bridge_max_width, 0.8),
    pad_min        = max(0.03, bridge_pad),
    tail_minutes   = tail_minutes,
    tail_relax     = tail_relax
  )
  df_suf_b$intensity <- br$yb

  # 4) run hybrid on suffix
  df_h_suf <- baseline_hybrid_sm(
    df_sample = df_suf_s,
    df_blank  = df_suf_b,
    pre_win       = pre_win,  pre_p  = pre_p,
    noise_factor  = noise_factor,
    min_peak_dist = min_peak_dist, min_seg_len = min_seg_len,
    als_lambda    = als_lambda,     als_p      = als_p,
    show_plot     = FALSE
  )

  # 5) 1-min guard
  guard_min <- 1.0; eps_floor <- 0
  j_guard <- which(df_h_suf$time <= df_h_suf$time[1] + guard_min)
  if (length(j_guard)) {
    iL <- j_guard[1]; iR <- tail(j_guard, 1); end_val <- df_h_suf$baseline_local[iR]
    if (end_val <= eps_floor) {
      df_h_suf$baseline_local[j_guard] <- eps_floor
    } else {
      df_h_suf$baseline_local[j_guard] <- approx(
        x = c(df_h_suf$time[iL], df_h_suf$time[iR]),
        y = c(eps_floor,         end_val),
        xout = df_h_suf$time[j_guard], rule = 2
      )$y
    }
  }

  # 6) stitch back
  df_h <- data.frame(
    time           = time,
    raw_diff       = residual_true,
    smooth_diff    = NA_real_,
    baseline_local = 0,
    corrected      = residual_true
  )
  j <- i0:length(time)
  df_h$smooth_diff[j]    <- df_h_suf$smooth_diff
  df_h$baseline_local[j] <- df_h_suf$baseline_local
  df_h$corrected[j]      <- df_h$raw_diff[j] - df_h$baseline_local[j]

  # cosmetic smoothing for plotting
  dt  <- median(diff(df_h$time))
  nsg <- max(5L, 2L*floor((0.15/dt)/2) + 1L)
  df_h$corrected_smooth <- tryCatch(signal::sgolayfilt(df_h$corrected, p = 5, n = nsg),
                                    error = function(e) df_h$corrected)

  attr(df_h, "inj_start")  <- inj_start
  attr(df_h, "inj_end")    <- inj_end
  attr(df_h, "inj_vol_ml") <- attr(df_sample, "inj_vol_ml", 0.1)

  if (isTRUE(show_plots)) {
    p <- ggplot2::ggplot(df_h, ggplot2::aes(time)) +
      ggplot2::geom_line(ggplot2::aes(y = corrected),         colour = "grey60", linewidth = 0.4) +
      ggplot2::geom_line(ggplot2::aes(y = corrected_smooth),  colour = "black",   linewidth = 0.8) +
      ggplot2::geom_line(ggplot2::aes(y = baseline_local),    colour = "dodgerblue", linetype = 2) +
      ggplot2::annotate("rect", xmin = inj_start, xmax = inj_end, ymin = -Inf, ymax = Inf,
                        alpha = .06, fill = "grey40") +
      ggplot2::labs(title = "Hybrid baseline applied only after injector",
                    x = "Time (min)", y = "Absorbance (mAU)") +
      ggplot2::theme_minimal()
    print(p)
  }

  list(df_hybrid = df_h, shift_min = al$shift_min,
       injector = list(start = inj_start, end = inj_end))
}
