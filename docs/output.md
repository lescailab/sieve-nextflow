# lescailab/sieve: Output

This page describes published files produced by `main.nf` through the workflow `output` block. Paths are relative to `--outdir`; the cohort directory is controlled by `--cohort_id` and defaults to `cohort`.

Detailed interpretation guidance is in the [extended output guide](../guidelines/outputs-detailed.md).

## Directory layout

```text
<outdir>/
├── <cohort_id>/
│   ├── data/
│   ├── real_experiments/
│   ├── null_baselines/
│   ├── attribution_comparison/
│   ├── discovery/
│   ├── ablation/
│   ├── epistasis/
│   └── validation/
└── pipeline_info/
```

The exact contents depend on `--execute_step` and shortcut artefacts.

## Key outputs

| Path | Contents |
| --- | --- |
| `<cohort_id>/data/sample_sex.tsv` | Effective sex map used downstream, either inferred or copied from `--sex_map`. |
| `<cohort_id>/data/preprocessed.pt` | Encoded SIEVE dataset used for training and explainability. |
| `<cohort_id>/real_experiments/L3/cross_fold/cv_output/fold_*/` | Cross-validation fold outputs when CV training runs. |
| `<cohort_id>/real_experiments/L3/training/best_checkpoint.pt` | Selected best checkpoint from CV training. |
| `<cohort_id>/real_experiments/L3/training/best_fold_config.yaml` | Configuration paired with the selected checkpoint. |
| `<cohort_id>/real_experiments/L3/training/best_model.pt` | Model produced by the single-training path when `--cv_folds 1`. |
| `<cohort_id>/real_experiments/L3/training/config.yaml` | Configuration used by the single-training path when `--cv_folds 1`. |
| `<cohort_id>/real_experiments/L3/training/results.yaml` | Training metrics from the single-training path when `--cv_folds 1`. |
| `<cohort_id>/real_experiments/L*/attributions/explain_output/` | Explainability outputs, including variant rankings, gene rankings, interactions, and attribution arrays where produced. |
| `<cohort_id>/null_baselines/L*/training/` | Null-baseline model artefacts and `preprocessed_NULL.pt` for L3 when the null branch runs. |
| `<cohort_id>/null_baselines/L*/attributions/explain_output/` | Null-baseline explainability outputs. |
| `<cohort_id>/attribution_comparison/L*/` | Real-vs-null comparison summaries, calibrated rankings, and chrX-corrected ranking outputs. |
| `<cohort_id>/discovery/gene_list_by_delta_rank.tsv` | Primary gene ranking derived from bootstrap-resampled null attributions. Delta-rank is scale-free and stable across annotation levels. |
| `<cohort_id>/discovery/gene_list_by_z_attribution.tsv` | Secondary diagnostic gene ranking. The per-chromosome z-score flattens genome-wide signal and is retained for Manhattan-plot visualisation and continuity with earlier runs. |
| `<cohort_id>/discovery/variant_significance_rankings.csv` | Variant-level ranking corresponding to the published discovery results. |
| `<cohort_id>/ablation/comparison_levels/` | Cross-level ablation summaries and comparison plot. |
| `<cohort_id>/ablation/gene_significance_rankings_delta/L*/` | Gene lists ranked by delta rank. |
| `<cohort_id>/ablation/gene_significance_rankings_zattr/L*/` | Gene lists ranked by z-attribution. |
| `<cohort_id>/ablation/variants_significance_rankings/` | Variant significance ranking table emitted by gene-list generation. |
| `<cohort_id>/epistasis/L3/epistasis_audit/` | Epistasis validation output when interactions are available. |
| `<cohort_id>/epistasis/L3/gene_interactions/` | Gene interaction tables and network edge/node tables. |
| `<cohort_id>/validation/` | Discovery validation report and collected plots when selected. |
| `pipeline_info/` | Nextflow trace, timeline, report, DAG, parameter snapshot, and software versions. |

## Notes

- `workflow.output.mode` follows `--publish_dir_mode`, which defaults to `copy`.
- `--execute_step` can suppress whole branches and their outputs.
- `--sex_map`, `--preprocessed_data`, `--best_params`, and `--best_checkpoint`/`--checkpoint_config` can cause published files to reflect supplied artefacts rather than newly generated files.
- Epistasis validation is conditional on non-empty interaction rows from explainability output; other epistasis audit and aggregation steps may still run when `epistasis` is selected.

## Primary discovery selector

`gene_list_by_delta_rank.tsv` is the primary gene result. `SIEVE_BOOTSTRAP_NULL_CALIBRATION` derives delta-rank from bootstrap-resampled null attributions, providing a scale-free ranking that is stable across annotation levels. `gene_list_by_z_attribution.tsv` is a secondary diagnostic based on a per-chromosome z-score, which flattens genome-wide signal; the pipeline retains it for Manhattan-plot visualisation and continuity with earlier runs. `variant_significance_rankings.csv` carries the variant-level equivalent.

The selector is controlled by:

| Parameter | Default | Role |
| --- | --- | --- |
| `--bootstrap_top_k` | `50,100,200,500,1000` | Comma-separated top-k thresholds for delta-rank overlap summaries. |
| `--bootstrap_gene_delta_rank_aggregation` | `max` | Aggregates per-variant delta-rank to gene level with `max` or `mean`. |
| `--bootstrap_exclude_sex_chroms` | `false` | Drops sex-chromosome variants before bootstrap calibration when enabled. |
| `--bootstrap_min_variants_per_gene` | `10` | Minimum variants required to compute gene-level statistics. |
