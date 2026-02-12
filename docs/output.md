# nf-core/sieve: Output

This document describes the output produced by `nf-core/sieve`.
All paths below are relative to the pipeline `--outdir`.

## Directory layout

- `sex_inference/`
  - `sample_sex.tsv` (when inference runs)
  - optional diagnostic plots/YAML files
- `preprocess/`
  - `preprocessed.pt`
- `grid_search/`
  - `runs/` per-grid training artifacts
  - `selection/`
    - `train_grid_summary.tsv`
    - `best_params.yaml`
    - `best_run_id.txt`
- `cross_validation/`
  - `train/` CV run outputs (`fold_*`, `cv_results.yaml`)
  - `selection/`
    - `best_checkpoint.pt`
    - `best_fold_config.yaml`
    - `best_fold_id.txt`
    - `cv_folds_summary.tsv`
- `explainability/real/`
  - `sieve_variant_rankings.csv`
  - `sieve_gene_rankings.csv`
  - `sieve_interactions.csv`
  - additional explainability files
- `ablation/`
  - `runs/` training outputs for levels `L0`-`L3`
  - `summary/`
    - `ablation_summary.tsv`
    - `ablation_summary.yaml`
- `null_baseline/`
  - `dataset/preprocessed_NULL.pt`
  - `train/` null-model training outputs
  - `explain/` null explainability outputs
  - `comparison/`
    - `comparison_summary.yaml`
    - additional comparison tables/plots
- `epistasis/`
  - `epistasis_validation.csv` and related files (only when interactions are present)
- `discovery_validation/`
  - `validation_report.yaml` and related files
- `pipeline_info/`
  - Nextflow execution reports (trace, timeline, report, DAG)
  - `nf_core_sieve_software_versions.yml`
  - `params.json`

## Notes

- The best model path for explainability is `cross_validation/selection/best_checkpoint.pt`.
- Epistasis validation is conditionally executed only when `sieve_interactions.csv` has interaction rows.
- Null baseline branches run in parallel with epistasis once explainability outputs are available.
