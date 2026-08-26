# HPLC Peptide Concentration Calculator

A desktop application for calculating peptide concentrations from HPLC UV peak areas at 214 nm, based on the Kuipers & Gruppen (2007) method for estimating extinction coefficients.

## Features

- **Peptide Sequence Input**: Enter peptide sequences using standard one-letter amino acid codes
- **Automatic ε₂₁₄ Calculation**: Uses the Kuipers & Gruppen (2007) method with special tripeptide corrections
- **Concentration Calculation**: Calculates peptide concentration from AUC, flow rate, and other HPLC parameters
- **Dilution Factor Support**: Apply dilution factors to get final concentrations
- **Real-time Updates**: All calculations update automatically as you type
- **Clean Interface**: Modern, calculator-like UI optimized for desktop use

## Installation

### Prerequisites
- Node.js (version 14 or higher)
- npm or yarn

### Setup
1. Navigate to the project directory:
   ```bash
   cd peptide-calculator
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm start
   ```

4. In a new terminal, run the Electron app:
   ```bash
   npm run electron-dev
   ```

### Building for Production

To create a distributable Windows application:

```bash
npm run build
npm run electron-pack
```

The built application will be in the `dist` folder.

## Usage

1. **Enter Peptide Sequence**: Type or paste your peptide sequence using standard one-letter codes (A-Z)
2. **Set HPLC Parameters**:
   - AUC (mAU·min): Peak area from your HPLC chromatogram
   - Flow Rate (mL/min): HPLC flow rate
   - Injection Volume (mL): Sample injection volume
   - Pathlength (cm): UV cell pathlength
3. **Apply Dilution Factor**: Enter dilution factor if applicable (e.g., 10 for 1:10 dilution)
4. **View Results**: The app will automatically calculate and display:
   - Extinction coefficient (ε₂₁₄)
   - Peak concentration (M and μM)
   - Final concentration with dilution factor

## Example

For a peptide sequence "ACDEFGHIKLMNPQRSTVWY":
- AUC: 1000 mAU·min
- Flow Rate: 1.0 mL/min
- Injection Volume: 0.1 mL
- Pathlength: 1.0 cm
- Dilution Factor: 1.0

The app will calculate the extinction coefficient and concentration automatically.

## Scientific Background

This calculator implements the method described in:
> Kuipers, B. J., & Gruppen, H. (2007). Prediction of molar extinction coefficients of proteins and peptides using UV absorption of the constituent amino acids at 214 nm to enable quantitative reverse phase high-performance liquid chromatography-mass spectrometry analysis. *Journal of Agricultural and Food Chemistry*, 55(14), 5445-5451.

The method includes:
- Standard amino acid contributions at 214 nm
- Special corrections for tripeptides (GGG, GPG, PGG, GGP)
- Proper handling of proline contributions
- Peptide bond contributions

## Technical Details

- **Frontend**: React 18 with modern hooks
- **Desktop**: Electron for cross-platform desktop support
- **Styling**: CSS3 with modern design principles
- **Calculations**: Pure JavaScript implementation of the R functions

## License

This project is based on scientific methods and is intended for research and educational purposes.


