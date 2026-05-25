# lescailab/sieve: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.0dev - 2026-05-25

Sync with upstream `sieve-project` v1.2.0 → v1.3.0 and add execution shortcuts.

### `Added`

- **Fixed-parameter shortcut for skipping the hyperparameter grid.**
  When `--train_lr`, `--train_lambda_attr`, and `--train_latent_dim` are all
  provided, the Cartesian grid is bypassed; the new `SIEVE_EMIT_BEST_PARAMS`
  module materialises the in-memory params map as `best_params.yaml` so the
  same downstream channels flow without further changes.
- **Single-training mode via `--cv_folds 0|1`.** When cross-validation is not
  required, the main model is trained once with `SIEVE_TRAIN_SINGLE`
  (`--val-split` used for the train/validation split), skipping
  `SIEVE_TRAIN_CV` and `SIEVE_SELECT_BEST_CHECKPOINT`.
- **Delta-rank from bootstrap calibration is now the primary top-k selector
  in the main branch.** `SIEVE_GENERATE_GENE_LIST` runs at the end of
  `TRAIN_AND_EXPLAIN` (not only inside `ABLATION`) and emits
  `gene_list_by_delta_rank.tsv`, `gene_list_by_z_attribution.tsv` (secondary
  diagnostic), and `variant_significance_rankings.csv` under
  `<cohort>/discovery/`.
- Surface-area sync with upstream `sieve-project` 1.2.0 → 1.3.0:
  - `--train_classifier_type` (`flatten` | `attention_pool`) (new in 1.3.0)
  - `--train_num_heads`, `--train_chunk_overlap`, `--train_class_weighting`
  - `--pc_map`, `--num_pcs` (population-structure covariates)
  - `--explain_n_steps`, `--explain_max_variants`, `--explain_top_k_variants`,
    `--explain_top_k_interactions`, `--explain_attention_threshold`,
    `--explain_attention_threshold_mode`, `--explain_attention_percentile`,
    `--explain_aggregation_method`, `--explain_skip_ig`,
    `--explain_skip_attention`, `--explain_batch_size`
  - `--bootstrap_top_k`, `--bootstrap_gene_delta_rank_aggregation`,
    `--bootstrap_exclude_sex_chroms`, `--bootstrap_min_variants_per_gene`
    (plus `bootstrap_summary.yaml` and `bootstrap_gene_stats.csv` outputs)
  - `--compare_exclude_sex_chroms`, `--chrx_include_sex_chroms`

### `Changed`

- `validateSieveArguments` now also validates `--cv_folds`, the all-or-none
  rule for fixed training hyperparameters, the `--train_classifier_type`
  enum, and warns about the source-of-best-params precedence
  (`--best_checkpoint` > `--best_params` > fixed `--train_*`).
- `nextflow_schema.json` lowered `cv_folds` minimum from 2 to 0 to allow
  single-training mode.

## v1.0.0dev - 2026-03-05

Initial release of lescailab/sieve, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- Complete SIEVE workflow implementation for case-control variant discovery
  - Sex inference module for chromosome-based sex determination
  - VCF preprocessing with annotation level encoding (L0-L3)
  - Hyperparameter grid search with parallel training
  - Cross-validation training with best parameter selection
  - Best checkpoint selection based on AUC/accuracy/loss metrics
  - Model explainability with variant attribution analysis
  - Ablation experiments across annotation levels (L0, L1, L2, L3)
  - **Ablation ranking comparison** with Jaccard similarity analysis and level-specific variant identification
  - Null baseline comparison with permuted datasets
  - Conditional epistasis validation for interaction discovery
  - Discovery validation with optional external resources (ClinVar, GWAS, GO)
- Comprehensive plot collection and aggregation across all workflow stages
- Support for resumable workflows with artifact injection (`--preprocessed_data`, `--best_params`, `--best_checkpoint`)
- Selective step execution via `--execute_step` parameter
- Full test coverage with nf-test component tests
  - Component tests for ablation comparison, checkpoint selection, parameter selection
  - **Test for empty plot bundle handling** to ensure robustness on cloud storage

### `Fixed`

- **Handling of empty ablation plot bundles on cloud outputs** - ensures graceful fallback when no plot files are found
- Implicit closure parameter warnings for strict syntax compliance
  - Updated `ablation_compare`, `select_best_params`, and `collect_plots` modules
  - Fixed unused parameter warning in main workflow CLI argument parsing
- Suppressed nf-core specific linting checks for custom pipeline template
- Excluded test assets from pre-commit hooks and Prettier formatting
- Files unchanged warnings for custom pipeline templates

### `Dependencies`

- Nextflow >= 25.04.0 (strict syntax support)
- nf-schema plugin v2.5.1 for parameter validation
- SIEVE container: `ghcr.io/lescailab/sieve-container:f8e7db75b531e7d4`
- Python packages: pandas, numpy, scikit-learn, matplotlib, seaborn, pyyaml
- Support for Docker, Singularity, Apptainer, Conda, Podman

### `Deprecated`

N/A - Initial release
