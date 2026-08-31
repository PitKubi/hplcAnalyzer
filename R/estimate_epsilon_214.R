# Molar absorptivity at 214 nm.
#
# Two functions live here on purpose. published_epsilon_214() is the Kuipers and Gruppen
# model exactly as printed, so the paper can always be audited against the code.
# estimate_epsilon_214() is what the pipelines and the app call, and it applies the
# recalibration measured on our own data. Keeping them apart means the correction can be
# seen, argued with and reverted without touching the published model.

PUBLISHED_TRYPTOPHAN_EPSILON_214 <- 29050

# Measured on two peptide purity batches, 31 August 2026: 130 injections quantified
# at both 214 and 280 nm, of which 71 pass an 80 percent purity gate. The 214-to-280
# concentration ratio is taken within one injection, so sample amount, dilution and any
# whole-batch offset cancel and only the extinction model is left. That ratio tracks tryptophan
# and nothing else (Spearman rho -0.76, p < 1e-13): median 1.14 with no Trp, 0.76 with one,
# 0.68 with two. A two-parameter least-squares fit on the 71 gated injections, bootstrapped
# 4000 times, gives the values below. Tyrosine and phenylalanine, fitted freely in the same
# way, stay at their published values and are therefore left alone.
#
# Fitting each batch separately gives 15,300 and 18,200 for the tryptophan term, so it is not
# a batch artefact. Amino acid analysis agrees independently: tryptophan pulls the 214 nm
# channel away from it while 280 nm stays put.
MEASURED_TRYPTOPHAN_EPSILON_214 <- 17340  # 95 percent CI 14,519 to 19,569

# The two channels still sit about 12 percent apart once tryptophan is fixed, uniformly across
# every peptide, so a single scale is applied to everything that is not the tryptophan term.
# 1.118 is the ratio fit (95 percent CI 1.01 to 1.26). Anchored instead on amino acid analysis,
# using the 170 tryptophan-free peptides of the clean batch, it comes out 1.078. The two agree
# inside the interval and 1.118 is the better of the two on both criteria on this data, but
# this is the soft number of the pair: change it here and nowhere else.
NON_TRYPTOPHAN_EPSILON_214_SCALE <- 1.118

#' Molar absorptivity at 214 nm exactly as published
#'
#' The additive residue model of Kuipers and Gruppen (2007), with the four special
#' tripeptides of their Table 3. No correction of any kind is applied.
#'
#' @param sequence Character. Peptide one-letter code.
#' @return Numeric. eps214 in M^-1 cm^-1, or NA_real_ for anything that is not a
#'   sequence of the twenty standard one-letter codes.
#' @export
published_epsilon_214 <- function(sequence) {

  if (is.na(sequence) || !grepl("^[ACDEFGHIKLMNPQRSTVWY]+$", sequence)) {
    return(NA_real_)
  }
  # Standard contributions from Table 5
  coeffs <- c(
    PB = 923,   # peptide bond
    W  = PUBLISHED_TRYPTOPHAN_EPSILON_214,
    Y  = 5375,  # Tyr
    F  = 5200,  # Phe
    H  = 5125,  # His
    M  = 980,   # Met
    R  = 102,   # Arg
    Q  = 142,   # Gln
    N  = 136,   # Asn
    C  = 225,   # Cys
    G  = 21,    # Gly
    V  = 43,    # Val
    I  = 45,    # Ile
    L  = 45,    # Leu
    A  = 32,    # Ala
    S  = 34,    # Ser
    D  = 58,    # Asp
    K  = 41,    # Lys
    E  = 78,    # Glu
    T  = 41     # Thr
  )

  aas <- strsplit(sequence, "")[[1]]
  n_pb <- length(aas) - 1
  # Proline is deliberately absent from `coeffs` because Kuipers and Gruppen give it
  # 2675 only when it is NOT N-terminal, which is applied separately below. It must
  # still be a factor LEVEL here: levels not listed become NA and table() drops them,
  # so omitting it silently destroyed the count and the 2675 term never fired.
  cnt  <- table(factor(aas, c(names(coeffs), "P")))

  # **Special tripeptide cases** (Table 3)
  # Gly-Gly-Gly, Gly-Pro-Gly, Pro-Gly-Gly, Gly-Gly-Pro
  if (nchar(sequence) == 3) {
    tri <- toupper(sequence)
    special <- c(
      "GGG" = 1080,
      "GPG" = 3620,
      "PGG" =  950,
      "GGP" = 3880
    )
    if (tri %in% names(special)) {
      return(unname(special[tri]))
    }
  }

  # Start with peptide-bond contribution
  eps <- n_pb * coeffs["PB"]

  # Add every amino-acid contribution
  eps <- eps + sum(cnt[names(cnt) != "P"] * coeffs[names(cnt) != "P"], na.rm=TRUE)

  # Handle Proline: only non-N-terminal Pro (2675), per Table 5
  nP           <- ifelse(is.na(cnt["P"]), 0, cnt["P"])
  internal_P   <- if (substr(sequence,1,1)=="P") max(0, nP-1) else nP
  eps <- eps + internal_P * 2675

  return(unname(eps))
}

#' Estimate the sequence-specific eps214 used for quantitation
#'
#' The published Kuipers and Gruppen value with our measured recalibration applied: the
#' tryptophan term is replaced and everything else is scaled. See the constants at the top
#' of this file, and the "Recalibration of eps214" section of the README, for the data the
#' two numbers come from and how to change them.
#'
#' The four special tripeptides are scaled along with everything else. They carry no
#' tryptophan, so they take the same global scale as any other tryptophan-free peptide.
#'
#' @param sequence Character. Peptide one-letter code.
#' @return Numeric. eps214 in M^-1 cm^-1, or NA_real_ for an unusable sequence.
#' @export
estimate_epsilon_214 <- function(sequence) {

  published <- published_epsilon_214(sequence)
  if (is.na(published)) {
    return(NA_real_)
  }

  tryptophan_count <- lengths(regmatches(sequence, gregexpr("W", sequence, fixed = TRUE)))
  without_tryptophan <- published - PUBLISHED_TRYPTOPHAN_EPSILON_214 * tryptophan_count

  NON_TRYPTOPHAN_EPSILON_214_SCALE * without_tryptophan +
    MEASURED_TRYPTOPHAN_EPSILON_214 * tryptophan_count
}
