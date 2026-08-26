#' Read Agilent `.D` folder (raw trace)
#'
#' @importFrom magrittr %>%
#' @import chromConverter
#' @import dplyr
#' @param d_path Character. Path to the Agilent `.D` directory.
#' @param signal_wavelength Numeric. DAD signal wavelength (nm). Default 214.
#' @param signal_ref        Numeric. DAD reference wavelength (nm). Default 360.
#' @return A data.frame with columns:
#'   - **time** (minutes)
#'   - **intensity** (mAU)
#' @seealso \code{\link{baseline_als}}, \code{\link{baseline_hybrid_sm}}
#' @export
read_hplc_agilent <- function(d_path,
                              signal_wavelength = 214,
                              signal_ref        = 360) {
  chroms <- read_agilent_d(d_path,
                           what       = "chroms",
                           format_out = "data.frame",
                           data_format= "long")

  sel <- which(sapply(chroms, function(x) {
    dr <- attr(x, "detector_range")
    grepl(paste0("Sig=", signal_wavelength), dr) &&
      grepl(paste0("Ref=", signal_ref),      dr)
  }))
  if (!length(sel)) {
    stop("No matching DAD signal (",
         signal_wavelength, "/", signal_ref,
         ") found in ", basename(d_path))
  }

  df <- as.data.frame(chroms[[sel[1]]]) %>%
    arrange(rt) %>%
    rename(time = rt)


  #####################

  inj_ml <- 0.100  # default = 100 µL

  acq <- list.files(d_path, "^acq\\.txt$", full.names = TRUE,
                    ignore.case = TRUE, recursive = TRUE)
  if (length(acq)) {
    read_enc <- function(enc)
      tryCatch(readLines(file(acq[1], encoding = enc), warn = FALSE),
               error = function(e) character(0))

    lines <- read_enc("UTF-16LE")
    if (!length(lines)) lines <- read_enc("UTF-16BE")
    if (!length(lines)) lines <- read_enc("UTF-8")
    if (!length(lines)) lines <- read_enc("latin1")

    if (length(lines)) {
      # normalize micro signs (µ / μ) to 'u' to avoid encoding issues
      lines <- gsub("[\u00B5\u03BC]", "u", lines, perl = TRUE)

      # match: "Injection Volume: 300.00 uL" or "... 0.30 mL"
      rx <- "(?i)Injection\\s*Volume\\s*[:=]\\s*([0-9]+(?:[\\.,][0-9]+)?)\\s*([um]l)\\b"
      mm <- regexec(rx, lines, perl = TRUE)
      got <- regmatches(lines, mm)
      hit <- which(lengths(got) >= 3)[1]

      if (length(hit)) {
        num  <- as.numeric(sub(",", ".", got[[hit]][2]))
        unit <- tolower(got[[hit]][3])
        if (is.finite(num)) inj_ml <- if (unit == "ml") num else num / 1000
      }
    }
  }
  attr(df, "inj_vol_ml") <- inj_ml

  ############################



  return(df)
}
