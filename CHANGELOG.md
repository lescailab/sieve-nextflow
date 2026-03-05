# lescailab/sieve: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
