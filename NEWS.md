# hplcAnalyzer 0.7.2

* **Evidence that the integration change is an improvement, and one place where it is not.**
  A new README section with the measurements behind it.

  Subtracting a blank before integrating used to change the reported area by a median of 15.8
  percent, and by more than 5 percent on 53 of 57 runs. With the chord it is 1.6 percent, and more
  than 5 percent on 16. Whether a blank is in the folder is a fact about the plate, not the
  peptide.

  Against a collaborator's independently quantified workbook of the same 55 runs, the implied
  dilution factor tightens from a median 5.47 with relative spread 0.113 to **5.10 with spread
  0.100**, sitting on a factor of exactly 5.

  It does **not** improve agreement between the two wavelengths: the 214-to-280 ratio goes from a
  median 1.015, IQR 0.087, to 1.008, IQR 0.095. The chord recovers about the same fraction at both
  wavelengths, so that test cannot see the change.

