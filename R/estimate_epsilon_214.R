#' Estimate the sequence‐specific ε214 (Kuipers & Gruppen, 2007),
#' with special tripeptide corrections
#'
#' @param sequence Character. Peptide one‐letter code.
#' @return Numeric. ε214 in M⁻¹·cm⁻¹.
#' @export
estimate_epsilon_214 <- function(sequence) {

  if (is.na(sequence) || !grepl("^[ACDEFGHIKLMNPQRSTVWY]+$", sequence)) {
    # return NA (or whatever default) for blanks/invalids
    return(NA_real_)
  }
  # Standard contributions from Table 5 :contentReference[oaicite:10]{index=10}
  coeffs <- c(
    PB = 923,   # peptide bond
    W  = 29050, # Trp
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

  # **Special tripeptide cases** (Table 3) :contentReference[oaicite:11]{index=11}
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

  # Start with peptide‐bond contribution
  eps <- n_pb * coeffs["PB"]

  # Add every amino‐acid contribution
  eps <- eps + sum(cnt[names(cnt) != "P"] * coeffs[names(cnt) != "P"], na.rm=TRUE)

  # Handle Proline: only non‐N‐terminal Pro (2675), per Table 5 :contentReference[oaicite:12]{index=12}
  nP           <- ifelse(is.na(cnt["P"]), 0, cnt["P"])
  internal_P   <- if (substr(sequence,1,1)=="P") max(0, nP-1) else nP
  eps <- eps + internal_P * 2675

  return(eps)
}
