# Detailed Outputs

All paths are relative to `--outdir`. The cohort directory is `--cohort_id`, defaulting to `cohort`.

## High-level tree

```text
<outdir>/
├── <cohort_id>/
│   ├── data/
│   ├── real_experiments/
│   ├── null_baselines/
│   ├── attribution_comparison/
│   ├── ablation/
│   ├── epistasis/
│   └── validation/
└── pipeline_info/
```

## Data

```text
<cohort_id>/data/sample_sex.tsv
<cohort_id>/data/preprocessed.pt
```

`sample_sex.tsv` is the effective sex map. It may be inferred or copied from `--sex_map`.

`preprocessed.pt` is the SIEVE-ready tensor dataset. It may be generated from raw inputs or copied from `--preprocessed_data`.

## Real experiments

Primary L3 outputs:

```text
<cohort_id>/real_experiments/L3/cross_fold/cv_output/fold_*/
<cohort_id>/real_experiments/L3/training/best_checkpoint.pt
<cohort_id>/real_experiments/L3/training/best_fold_config.yaml
<cohort_id>/real_experiments/L3/training/cv_folds_summary.tsv
<cohort_id>/real_experiments/L3/attributions/explain_output/
```

Ablation real-training outputs are also published under:

```text
<cohort_id>/real_experiments/L0/
<cohort_id>/real_experiments/L1/
<cohort_id>/real_experiments/L2/
<cohort_id>/real_experiments/L3/
```

Inside attribution directories, key files include:

```text
sieve_variant_rankings.csv
sieve_gene_rankings.csv
sieve_interactions.csv
attributions.npz
```

## Null baselines

```text
<cohort_id>/null_baselines/L*/training/
<cohort_id>/null_baselines/L*/attributions/explain_output/
```

For the primary L3 null branch, training can include:

```text
preprocessed_NULL.pt
best_model.pt
config.yaml
results.yaml
training_history.yaml
```

Per-level ablation null branches publish selection-payload directories containing:

```text
best_model.pt
config.yaml
results.yaml
```

## Attribution comparison

```text
<cohort_id>/attribution_comparison/L*/
├── comparison_summary.yaml
├── calibrated_rankings.csv
├── comparison_output/
└── corrected/
```

Important files:

| File | Meaning |
| --- | --- |
| `comparison_summary.yaml` | Summary emitted by real-vs-null attribution comparison. |
| `comparison_output/variant_rankings_with_significance.csv` | Variant ranking table with significance fields when produced. |
| `comparison_output/significant_variants.csv` | Significant variant subset when produced. |
| `calibrated_rankings.csv` | Bootstrap-calibrated ranking table. |
| `corrected/corrected_variant_rankings.csv` | Variant rankings after chrX-bias correction. |
| `corrected/corrected_gene_rankings.csv` | Gene-level corrected rankings. |
| `corrected/correction_report.yaml` | Correction summary. |

## Ablation

```text
<cohort_id>/ablation/comparison_levels/
<cohort_id>/ablation/gene_significance_rankings_delta/L*/
<cohort_id>/ablation/gene_significance_rankings_zattr/L*/
<cohort_id>/ablation/variants_significance_rankings/
```

Key files:

```text
ablation_summary.tsv
ablation_summary.yaml
ablation_jaccard_matrix.tsv
level_specific_variants.tsv
ablation_comparison_plot.png
gene_list_by_delta_rank.tsv
gene_list_by_z_attribution.tsv
variant_significance_rankings.csv
```

The current output target for `variant_significance_rankings.csv` is shared across levels, so repeated L0-L3 emissions can publish to the same directory.

## Epistasis

```text
<cohort_id>/epistasis/L3/epistasis_audit/
<cohort_id>/epistasis/L3/gene_interactions/
```

Key files:

```text
epistasis_validation.csv
gene_pair_interactions.csv
gene_interaction_network_edges.csv
gene_interaction_network_nodes.csv
gene_interaction_summary.yaml
```

`epistasis_validation.csv` is emitted only when the real explainability interaction file contains non-empty interaction rows.

## Validation and plots

```text
<cohort_id>/validation/validation_report.yaml
<cohort_id>/validation/validation_output/
<cohort_id>/validation/plots/
<cohort_id>/validation/plots_manifest.tsv
```

Validation can use supplied reference resources or downloaded references. Plot collection depends on plot-source directories produced by selected upstream steps.

`SIEVE_COLLECT_PLOTS` searches those source directories for PNG, JPEG, SVG, PDF, EPS and TIFF files. It publishes them under `<cohort_id>/validation/plots/` with sequential filename prefixes and writes the source-to-destination mapping to `<cohort_id>/validation/plots_manifest.tsv`. When no supported plot files are available, it writes `<cohort_id>/validation/plots/0000__no_plots_found.txt`.

## Pipeline info

```text
pipeline_info/execution_timeline_<timestamp>.html
pipeline_info/execution_report_<timestamp>.html
pipeline_info/execution_trace_<timestamp>.txt
pipeline_info/pipeline_dag_<timestamp>.html
pipeline_info/params_<timestamp>.json
pipeline_info/nf_core_sieve_software_versions.yml
```

Use these files to audit command parameters, runtime behaviour, task failures, and software versions.
