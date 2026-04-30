# lescailab/sieve: Output

This page describes published files produced by `main.nf` through the workflow `output` block. Paths are relative to `--outdir`; the cohort directory is controlled by `--cohort_id` and defaults to `cohort`.

Detailed interpretation guidance is in the [extended output guide](../guidelines/docs/outputs-detailed.md).

## Directory layout

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

The exact contents depend on `--execute_step` and shortcut artifacts.

## Key outputs

| Path | Contents |
| --- | --- |
| `<cohort_id>/data/sample_sex.tsv` | Effective sex map used downstream, either inferred or copied from `--sex_map`. |
| `<cohort_id>/data/preprocessed.pt` | Encoded SIEVE dataset used for training and explainability. |
| `<cohort_id>/real_experiments/L3/cross_fold/cv_output/fold_*/` | Cross-validation fold outputs when CV training runs. |
| `<cohort_id>/real_experiments/L3/training/best_checkpoint.pt` | Selected best checkpoint from CV training. |
| `<cohort_id>/real_experiments/L3/training/best_fold_config.yaml` | Configuration paired with the selected checkpoint. |
| `<cohort_id>/real_experiments/L*/attributions/explain_output/` | Explainability outputs, including variant rankings, gene rankings, interactions, and attribution arrays where produced. |
| `<cohort_id>/null_baselines/L*/training/` | Null-baseline model artifacts and `preprocessed_NULL.pt` for L3 when the null branch runs. |
| `<cohort_id>/null_baselines/L*/attributions/explain_output/` | Null-baseline explainability outputs. |
| `<cohort_id>/attribution_comparison/L*/` | Real-vs-null comparison summaries, calibrated rankings, and chrX-corrected ranking outputs. |
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
- `--sex_map`, `--preprocessed_data`, `--best_params`, and `--best_checkpoint`/`--checkpoint_config` can cause published files to reflect supplied artifacts rather than newly generated files.
- Epistasis validation is conditional on non-empty interaction rows from explainability output; other epistasis audit and aggregation steps may still run when `epistasis` is selected.
