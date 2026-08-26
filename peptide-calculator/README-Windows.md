# Windows Desktop App - HPLC Peptide Calculator

**Built by Peter Kubiniok**

## Quick Setup for Windows Users

### Option 1: Use the Batch File (Easiest)
1. Double-click `windows-build.bat`
2. Wait for the build to complete
3. Go to `dist\windows-package\` folder
4. Double-click `run-app.bat` to start the calculator

### Option 2: Manual Setup
1. **Install Node.js** from https://nodejs.org (LTS version)
2. **Open Command Prompt** in this folder
3. **Install dependencies:**
   ```
   npm install
   ```
4. **Build the app:**
   ```
   npm run build
   ```
5. **Run the app:**
   ```
   npm run electron
   ```

## What You Get

- **Professional calculator interface** for HPLC peptide analysis
- **Real-time calculations** as you type
- **Exact implementation** of Kuipers & Gruppen (2007) method
- **Dilution factor support**
- **Your name prominently displayed** in the app

## Features

- Enter peptide sequences (one-letter codes)
- Set HPLC parameters (AUC, flow rate, injection volume, pathlength)
- Apply dilution factors
- Get instant concentration calculations
- Clean, modern interface

## Example Usage

1. Enter sequence: `ACDEFGHIKLMNPQRSTVWY`
2. Set AUC: `1000` mAU·min
3. Set flow rate: `1.0` mL/min
4. Add dilution factor: `10`
5. Get results instantly!

The app will calculate:
- Extinction coefficient (ε₂₁₄)
- Peak concentration (M and μM)
- Final concentration with dilution

## Scientific Reference

Based on: Kuipers, B. J., & Gruppen, H. (2007). Prediction of molar extinction coefficients of proteins and peptides using UV absorption of the constituent amino acids at 214 nm to enable quantitative reverse phase high-performance liquid chromatography-mass spectrometry analysis. *Journal of Agricultural and Food Chemistry*, 55(14), 5445-5451.

---

**Built by Peter Kubiniok** - Professional HPLC Analysis Tool

