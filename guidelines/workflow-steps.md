# Workflow Steps

This page explains the defined `--execute_step` names and the subworkflows they activate.

## Step names

Stable step names:

```text
sex, preprocess, grid, cv, explain, ablation, null, epistasis, validation, plots
```

Unset `--execute_step` means all of them. `--execute_step all` is equivalent.

## Sex

Purpose: create the effective `sample_sex.tsv`.

Implementation:

- Uses `--sex_map` directly when provided.
- Otherwise calls `SIEVE_INFER_SEX`.
- Publishes the effective map through `SIEVE_EMIT_SEX_MAP`.

Key output:

```text
<cohort_id>/data/sample_sex.tsv
```

## Preprocess

Purpose: encode raw VCF and phenotype data into a SIEVE tensor dataset.

Implementation:

`SIEVE_PREPROCESS` runs:

```text
sieve-preprocess \
  --vcf <vcf> \
  --phenotypes <phenotypes> \
  --output preprocessed.pt \
  --sex-map <sex_map> \
  --genome-build <build>
```

Shortcut:

```text
--preprocessed_data /path/to/preprocessed.pt
```

Key output:

```text
<cohort_id>/data/preprocessed.pt
```

## Grid

Purpose: train candidate single-split models and select the best parameter set.

Implementation:

- `buildTrainingGrid()` expands `grid_lr`, `grid_lambda_attr`, `grid_latent_dim`, `grid_hidden_dim`, and `grid_num_attention_layers`.
- `SIEVE_TRAIN_SINGLE_GRID` runs one training process per grid combination.
- `SIEVE_SELECT_BEST_PARAMS` emits `best_params.yaml`.
- When you supply all three fixed parameters, `SIEVE_EMIT_BEST_PARAMS` materialises the in-memory parameter map as `best_params.yaml`. This preserves the downstream channel shape while bypassing `SIEVE_TRAIN_SINGLE_GRID` and `SIEVE_SELECT_BEST_PARAMS`.

Shortcut:

```text
--best_params /path/to/best_params.yaml
```

If `--best_checkpoint` and `--checkpoint_config` are supplied without `--best_params`, the checkpoint config is used as the best-parameter source for downstream branches.

## CV

Purpose: train cross-validation folds and select the best checkpoint.

Implementation:

- `SIEVE_TRAIN_CV` creates `cv_output/fold_*`.
- `SIEVE_SELECT_BEST_CHECKPOINT` emits `best_checkpoint.pt`, `best_fold_config.yaml`, `best_fold_id.txt`, and `cv_folds_summary.tsv`.

Shortcut:

```text
--best_checkpoint /path/to/best_model.pt --checkpoint_config /path/to/config.yaml
```

Key outputs:

```text
<cohort_id>/real_experiments/L3/cross_fold/cv_output/fold_*/
<cohort_id>/real_experiments/L3/training/best_checkpoint.pt
<cohort_id>/real_experiments/L3/training/best_fold_config.yaml
```

## Explain

Purpose: run SIEVE explainability on the selected real-data checkpoint.

Implementation:

```text
sieve-explain \
  --experiment-dir _exp_dir \
  --preprocessed-data <preprocessed.pt> \
  --output-dir explain_output
```

Key outputs:

```text
sieve_variant_rankings.csv
sieve_gene_rankings.csv
sieve_interactions.csv
explain_output/attributions.npz
```

Published under:

```text
<cohort_id>/real_experiments/L3/attributions/
```

## Null

Purpose: create a shuffled/null baseline, train a null model, explain it, and compare real-vs-null attributions.

Implementation:

- `SIEVE_CREATE_NULL_BASELINE` emits `preprocessed_NULL.pt`.
- `SIEVE_TRAIN_SINGLE_NULL` trains the null model.
- `SIEVE_EXPLAIN_NULL` emits null rankings.
- `SIEVE_COMPARE_ATTRIBUTIONS_RAW` compares real and null variant rankings.
- `SIEVE_BOOTSTRAP_NULL_CALIBRATION` calibrates null rankings.
- `SIEVE_CORRECT_CHRX_BIAS` emits corrected rankings.

Published under:

```text
<cohort_id>/null_baselines/L3/
<cohort_id>/attribution_comparison/L3/
```

## Ablation

Purpose: repeat training and attribution comparison for annotation levels `L0`, `L1`, `L2`, and `L3`.

Implementation:

- Real ablation training: `SIEVE_TRAIN_SINGLE_ABLATION`
- Per-level real explainability: `SIEVE_EXPLAIN_ABLATION`
- Per-level null training and explainability: `SIEVE_TRAIN_SINGLE_NULL_ABLATION`, `SIEVE_EXPLAIN_NULL_ABLATION`
- Per-level comparison and correction: `SIEVE_COMPARE_ATTRIBUTIONS_ABL`, `SIEVE_BOOTSTRAP_ABL`, `SIEVE_CORRECT_CHRX_BIAS_ABL`
- `SIEVE_ABLATION_COMPARE` reads the per-level training selection payloads and produces `ablation_summary.tsv` and `ablation_summary.yaml` from performance metrics.
- `SIEVE_ABLATION_RANKING_COMPARE` compares the per-level corrected variant rankings and produces `ablation_jaccard_matrix.tsv` and `level_specific_variants.tsv`.
- Gene lists and the combined comparison plot: `SIEVE_GENERATE_GENE_LIST`, `SIEVE_PLOT_ABLATION_COMPARISON`

Published under:

```text
<cohort_id>/real_experiments/L*/
<cohort_id>/null_baselines/L*/
<cohort_id>/attribution_comparison/L*/
<cohort_id>/ablation/
```

When `ablation` is selected, `SIEVE_CREATE_NULL_BASELINE` runs automatically to produce the shuffled null dataset, regardless of whether `null` is also selected. Running `--execute_step ablation` therefore always produces per-level null comparisons. Including `null` additionally runs the full L3 null training, explanation, and attribution comparison.

## Epistasis

Purpose: audit co-occurrence, validate interactions when present, estimate power, and aggregate gene interactions.

Implementation:

- `SIEVE_AUDIT_COOCCURRENCE` always runs when `epistasis` is selected.
- `SIEVE_VALIDATE_EPISTASIS` runs only when `sieve_interactions.csv` contains non-empty interaction rows.
- `SIEVE_EPISTASIS_POWER_ANALYSIS` uses co-occurrence outputs plus optional null attribution data.
- `SIEVE_AGGREGATE_GENE_INTERACTIONS` aggregates gene-level interaction tables and network files.

Published under:

```text
<cohort_id>/epistasis/L3/
```

## Validation

Purpose: compare discovery outputs against optional or downloaded reference resources.

Implementation:

- `SIEVE_DOWNLOAD_REFERENCES` runs only when `validation` is selected and no validation resources are supplied.
- `SIEVE_VALIDATE_DISCOVERIES` validates variant and gene rankings.

Published under:

```text
<cohort_id>/validation/
```

## Plots

Purpose: collect plots from upstream process output directories.

Implementation:

- `SIEVE_COLLECT_PLOTS` receives accumulated plot-source directories.
- Running only `--execute_step plots` can produce an empty or minimal plot collection if no selected upstream steps generated plot sources.
