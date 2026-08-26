/**
 * Estimate the sequence-specific ε214 (Kuipers & Gruppen, 2007),
 * with special tripeptide corrections
 * 
 * @param {string} sequence - Peptide one-letter code
 * @returns {number} ε214 in M⁻¹·cm⁻¹
 */
export function estimateEpsilon214(sequence) {
  if (!sequence || !/^[ACDEFGHIKLMNPQRSTVWY]+$/i.test(sequence)) {
    return NaN;
  }

  // Standard contributions from Table 5
  const coeffs = {
    PB: 923,   // peptide bond
    W: 29050,  // Trp
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


