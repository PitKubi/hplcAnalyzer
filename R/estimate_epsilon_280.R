#' Estimate the sequence-specific ε280 (Edelhoch / Pace et al. 1995)
#'
#' Uses the standard formula: ε280 = 5500·nTrp + 1490·nTyr + 125·n(S-S).
#' Disulfide state of cysteines is unknown for purity-check peptides, so this
#' implementation assumes ALL cysteines are reduced (free) and contributes 0
#' per Cys. If the peptide contains neither Trp nor Tyr, NA is returned —
#' such peptides effectively have no measurable absorbance at 280 nm and
#' cannot be quantified by UV at this wavelength.
#'
#' @param sequence Character. Peptide one-letter code.
#' @return Numeric. ε280 in M⁻¹·cm⁻¹, or NA_real_ if no Trp/Tyr.
#' @export
estimate_epsilon_280 <- function(sequence) {
  if (is.na(sequence) || !grepl("^[ACDEFGHIKLMNPQRSTVWY]+$", sequence)) {
    return(NA_real_)
  }
  aas <- strsplit(sequence, "")[[1]]
  nW  <- sum(aas == "W")
  nY  <- sum(aas == "Y")
  if (nW == 0 && nY == 0) return(NA_real_)
  unname(5500 * nW + 1490 * nY)
}
