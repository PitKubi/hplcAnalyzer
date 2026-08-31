// Molar absorptivity at 214 nm. These three constants are the same ones the R package
// carries in R/estimate_epsilon_214.R; the two implementations exist because the Electron
// calculator and the Shiny app run on different runtimes, and they must be changed together.
//
// Measured on two peptide purity batches, 31 August 2026: the 214-to-280
// concentration ratio, taken within one injection so amount and batch offset cancel, tracks
// tryptophan and nothing else (Spearman rho -0.76, p < 1e-13). A two-parameter fit on 71
// gated injections replaces the tryptophan term and scales everything else. Tyrosine and
// phenylalanine, fitted freely, stay at their published values. See the README section
// "Recalibration of eps214" for the evidence and for how to change the scale.
const PUBLISHED_TRYPTOPHAN_EPSILON_214 = 29050;
const MEASURED_TRYPTOPHAN_EPSILON_214 = 17340;   // 95 % CI 14,519 to 19,569
const NON_TRYPTOPHAN_EPSILON_214_SCALE = 1.118;  // 95 % CI 1.01 to 1.26; the soft number

/**
 * Molar absorptivity at 214 nm exactly as published (Kuipers & Gruppen, 2007),
 * with the four special tripeptides of their Table 3. No correction applied.
 *
 * @param {string} sequence - Peptide one-letter code
 * @returns {number} ε214 in M⁻¹·cm⁻¹
 */
export function publishedEpsilon214(sequence) {
  if (!sequence || !/^[ACDEFGHIKLMNPQRSTVWY]+$/i.test(sequence)) {
    return NaN;
  }

  // Standard contributions from Table 5
  const coeffs = {
    PB: 923,   // peptide bond
    W: PUBLISHED_TRYPTOPHAN_EPSILON_214,  // Trp
    Y: 5375,   // Tyr
    F: 5200,   // Phe
    H: 5125,   // His
    M: 980,    // Met
    R: 102,    // Arg
    Q: 142,    // Gln
    N: 136,    // Asn
    C: 225,    // Cys
    G: 21,     // Gly
    V: 43,     // Val
    I: 45,     // Ile
    L: 45,     // Leu
    A: 32,     // Ala
    S: 34,     // Ser
    D: 58,     // Asp
    K: 41,     // Lys
    E: 78,     // Glu
    T: 41      // Thr
  };

  const aas = sequence.toUpperCase().split('');
  const n_pb = aas.length - 1;
  
  // Count amino acids
  const cnt = {};
  aas.forEach(aa => {
    cnt[aa] = (cnt[aa] || 0) + 1;
  });

  // Special tripeptide cases (Table 3)
  if (sequence.length === 3) {
    const tri = sequence.toUpperCase();
    const special = {
      "GGG": 1080,
      "GPG": 3620,
      "PGG": 950,
      "GGP": 3880
    };
    if (special[tri] !== undefined) {
      return special[tri];
    }
  }

  // Start with peptide-bond contribution
  let eps = n_pb * coeffs.PB;

  // Add every amino-acid contribution (excluding Proline)
  Object.keys(cnt).forEach(aa => {
    if (aa !== 'P' && coeffs[aa]) {
      eps += cnt[aa] * coeffs[aa];
    }
  });

  // Handle Proline: only non-N-terminal Pro (2675)
  const nP = cnt['P'] || 0;
  const internal_P = sequence.toUpperCase().startsWith('P') ? Math.max(0, nP - 1) : nP;
  eps += internal_P * 2675;

  return eps;
}

/**
 * Estimate the sequence-specific ε214 used for quantitation: the published value with
 * the measured recalibration applied. The four special tripeptides carry no tryptophan,
 * so they take the same global scale as any other tryptophan-free peptide.
 *
 * @param {string} sequence - Peptide one-letter code
 * @returns {number} ε214 in M⁻¹·cm⁻¹
 */
export function estimateEpsilon214(sequence) {
  const published = publishedEpsilon214(sequence);
  if (!Number.isFinite(published)) {
    return NaN;
  }

  const tryptophanCount = (sequence.toUpperCase().match(/W/g) || []).length;
  const withoutTryptophan = published - PUBLISHED_TRYPTOPHAN_EPSILON_214 * tryptophanCount;

  return NON_TRYPTOPHAN_EPSILON_214_SCALE * withoutTryptophan +
    MEASURED_TRYPTOPHAN_EPSILON_214 * tryptophanCount;
}

/**
 * Calculate concentration from peak area
 * 
 * @param {number} area - Peak area (mAU·min)
 * @param {number} epsilon - Extinction coefficient (M⁻¹·cm⁻¹)
 * @param {number} injVolMl - Injection volume (mL), default 0.1
 * @param {number} flowRateMl - Flow rate (mL/min), default 1
 * @param {number} pathlengthCm - Cell pathlength (cm), default 1
 * @returns {object} Object with c_M (M) and c_uM (μM)
 */
export function calculatePeakConc(area, epsilon, injVolMl = 0.1, flowRateMl = 1, pathlengthCm = 1) {
  const absMl = area * flowRateMl / 1000;
  const c_M = absMl / (epsilon * pathlengthCm * injVolMl);
  const c_uM = c_M * 1e6;
  
  return {
    c_M: c_M,
    c_uM: c_uM
  };
}

/**
 * Calculate final concentration with dilution factor
 * 
 * @param {number} concentration - Original concentration (μM)
 * @param {number} dilutionFactor - Dilution factor (e.g., 10 for 1:10 dilution)
 * @returns {number} Final concentration (μM)
 */
export function applyDilutionFactor(concentration, dilutionFactor = 1) {
  return concentration * dilutionFactor;
}


