# 2025 AAA versus UV comparison

Four peptide purity batches measured twice: by amino acid analysis and by this package from
the 214 nm chromatogram. This is the earlier comparison, kept because two things in it are
still load-bearing. The per-batch ratio shows that a whole-batch scale factor is a recurring
feature rather than a one-off, and `aaa_cv` records the replicate precision of the reference
method, which sets how much of any disagreement is the reference's own noise.

## The tables are anonymised

The peptides were a collaborator's target list, so sample identifiers, sequences and the
source filenames carrying them have been removed. What replaces them keeps the physics and
drops the identity:

| Column | Meaning |
|---|---|
| `peptide_id` | a stable label, `PEP-0001` upward, assigned in sorted order |
| `sequence_length` | residues |
| `n_trp`, `n_tyr`, `n_phe`, `n_pro` | residue counts that drive absorptivity |
| `epsilon_214_published` | the Kuipers and Gruppen value for that sequence |

Every numeric measurement is untouched, so the calibration in
[Recalibration of eps214](../README.md#recalibration-of-eps214) can be checked against these
tables. The sequences themselves cannot be recovered from the counts.

Note that **none of these four batches contained a tryptophan peptide**, which is why the
214 nm tryptophan problem was invisible until batches with tryptophan arrived in 2026.

## Headline numbers

`metrics_by_batch.csv` and `metrics_overall.csv` hold n, RMSE, MAE, R2, bias and Lin's
concordance per batch. Median UV over AAA runs 1.16, 1.06, 1.02 and 0.94 across the four
batches. The reported AAA replicate CV has median 13.5 percent, interquartile 11.1 to 16.5.
