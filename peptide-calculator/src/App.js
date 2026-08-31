import React, { useState, useEffect } from 'react';
import { estimateEpsilon214, calculatePeakConc, applyDilutionFactor } from './calculations';
import './App.css';

function App() {
  const [sequence, setSequence] = useState('');
  const [flowRate, setFlowRate] = useState(1.0);
  const [auc, setAuc] = useState('');
  const [injectionVolume, setInjectionVolume] = useState(0.1);
  const [pathlength, setPathlength] = useState(1.0);
  const [dilutionFactor, setDilutionFactor] = useState(1.0);
  
  const [epsilon, setEpsilon] = useState(null);
  const [concentration, setConcentration] = useState(null);
  const [finalConcentration, setFinalConcentration] = useState(null);

  // Calculate epsilon when sequence changes
  useEffect(() => {
    if (sequence.trim()) {
      const eps = estimateEpsilon214(sequence.trim());
      setEpsilon(isNaN(eps) ? null : eps);
    } else {
      setEpsilon(null);
    }
  }, [sequence]);

  // Calculate concentration when parameters change
  useEffect(() => {
    if (epsilon && auc && !isNaN(parseFloat(auc))) {
      const conc = calculatePeakConc(
        parseFloat(auc),
        epsilon,
        parseFloat(injectionVolume),
        parseFloat(flowRate),
        parseFloat(pathlength)
      );
      setConcentration(conc);
      
      const final = applyDilutionFactor(conc.c_uM, parseFloat(dilutionFactor));
      setFinalConcentration(final);
    } else {
      setConcentration(null);
      setFinalConcentration(null);
    }
  }, [epsilon, auc, injectionVolume, flowRate, pathlength, dilutionFactor]);

  const handleSequenceChange = (e) => {
    const value = e.target.value.toUpperCase().replace(/[^ACDEFGHIKLMNPQRSTVWY]/g, '');
    setSequence(value);
  };

  const clearAll = () => {
    setSequence('');
    setFlowRate(1.0);
    setAuc('');
    setInjectionVolume(0.1);
    setPathlength(1.0);
    setDilutionFactor(1.0);
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>HPLC Peptide Concentration Calculator</h1>
        <p>Based on Kuipers &amp; Gruppen (2007) ε214 estimation, with the tryptophan term recalibrated on measured data</p>
      </header>

      <div className="calculator-container">
        <div className="input-section">
          <h2>Input Parameters</h2>
          
          <div className="input-group">
            <label htmlFor="sequence">Peptide Sequence (one-letter code):</label>
            <input
              id="sequence"
              type="text"
              value={sequence}
              onChange={handleSequenceChange}
              placeholder="e.g., ACDEFGHIKLMNPQRSTVWY"
              className="sequence-input"
            />
            <small>Only standard amino acids (A-Z) are allowed</small>
          </div>

          <div className="input-row">
            <div className="input-group">
              <label htmlFor="auc">AUC (mAU·min):</label>
              <input
                id="auc"
                type="number"
                value={auc}
                onChange={(e) => setAuc(e.target.value)}
                placeholder="0.0"
                step="0.001"
              />
            </div>

            <div className="input-group">
              <label htmlFor="flowRate">Flow Rate (mL/min):</label>
              <input
                id="flowRate"
                type="number"
                value={flowRate}
                onChange={(e) => setFlowRate(e.target.value)}
                step="0.1"
                min="0.1"
              />
            </div>
          </div>

          <div className="input-row">
            <div className="input-group">
              <label htmlFor="injectionVolume">Injection Volume (mL):</label>
              <input
                id="injectionVolume"
                type="number"
                value={injectionVolume}
                onChange={(e) => setInjectionVolume(e.target.value)}
                step="0.01"
                min="0.01"
              />
            </div>

            <div className="input-group">
              <label htmlFor="pathlength">Pathlength (cm):</label>
              <input
                id="pathlength"
                type="number"
                value={pathlength}
                onChange={(e) => setPathlength(e.target.value)}
                step="0.1"
                min="0.1"
              />
            </div>
          </div>

          <div className="input-group">
            <label htmlFor="dilutionFactor">Dilution Factor:</label>
            <input
              id="dilutionFactor"
              type="number"
              value={dilutionFactor}
              onChange={(e) => setDilutionFactor(e.target.value)}
              step="0.1"
              min="0.1"
            />
            <small>Enter 10 for 1:10 dilution, 100 for 1:100 dilution, etc.</small>
          </div>

          <button onClick={clearAll} className="clear-button">
            Clear All
          </button>
        </div>

        <div className="results-section">
          <h2>Results</h2>
          
          <div className="result-card">
            <h3>Extinction Coefficient (ε₂₁₄)</h3>
            {epsilon !== null ? (
              <div className="result-value">
                {epsilon.toLocaleString()} M⁻¹·cm⁻¹
              </div>
            ) : (
              <div className="result-placeholder">
                Enter a valid peptide sequence
              </div>
            )}
          </div>

          <div className="result-card">
            <h3>Peak Concentration</h3>
            {concentration ? (
              <div className="concentration-results">
                <div className="result-value">
                  {concentration.c_M.toExponential(3)} M
                </div>
                <div className="result-value">
                  {concentration.c_uM.toFixed(3)} μM
                </div>
              </div>
            ) : (
              <div className="result-placeholder">
                Enter AUC and valid sequence
              </div>
            )}
          </div>

          <div className="result-card final-result">
            <h3>Final Concentration (with dilution)</h3>
            {finalConcentration !== null ? (
              <div className="result-value large">
                {finalConcentration.toFixed(3)} μM
              </div>
            ) : (
              <div className="result-placeholder">
                Complete all inputs above
              </div>
            )}
          </div>
        </div>
      </div>

      <footer className="App-footer">
        <p>The tryptophan term and a global scale are recalibrated against measured 214/280 nm data; see the package README, section "Recalibration of eps214". Underlying model: Kuipers, B. J., &amp; Gruppen, H. (2007). Prediction of molar extinction coefficients of proteins and peptides using UV absorption of the constituent amino acids at 214 nm to enable quantitative reverse phase high-performance liquid chromatography-mass spectrometry analysis. Journal of Agricultural and Food Chemistry, 55(14), 5445-5451.</p>
        <p className="builder-credit">Built by Peter Kubiniok</p>
      </footer>
    </div>
  );
}

export default App;
