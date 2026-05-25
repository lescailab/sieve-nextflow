# Pipeline Overview

This page describes the pipeline structure as implemented in the codebase.

## Entry points

`main.nf` imports three workflows:

- `SIEVE` from `workflows/sieve.nf`
- `PIPELINE_INITIALISATION` from `subworkflows/local/utils_nfcore_sieve_pipeline`
- `PIPELINE_COMPLETION` from `subworkflows/local/utils_nfcore_sieve_pipeline`

The default `workflow {}` block performs this sequence:

```text
PIPELINE_INITIALISATION(...)
NFCORE_SIEVE()
PIPELINE_COMPLETION(...)
```

`NFCORE_SIEVE` is a named wrapper around `SIEVE()`. It emits the channels that are then published by the `output {}` block in `main.nf`.

## Main workflow

`workflows/sieve.nf` defines `workflow SIEVE`. It always invokes the `PREPROCESS` subworkflow, then conditionally invokes later subworkflows based on `--execute_step`:

| Subworkflow | File | Purpose |
| --- | --- | --- |
| `PREPROCESS` | `subworkflows/local/preprocess/main.nf` | Resolve sex map, preprocess raw data or ingest preprocessed data, run grid search or ingest best parameters, and prepare optional validation references. |
| `TRAIN_AND_EXPLAIN` | `subworkflows/local/train_and_explain/main.nf` | Run CV training, select the best checkpoint, explain real data, and run null-baseline comparison when requested. |
| `ABLATION` | `subworkflows/local/ablation/main.nf` | Train and explain L0-L3 ablation models, compare per-level rankings, and generate ablation summaries. |
| `EPISTASIS` | `subworkflows/local/epistasis/main.nf` | Audit co-occurrence, validate non-empty interaction results, perform power analysis, and aggregate gene interactions. |
| `VALIDATION` | `subworkflows/local/validation/main.nf` | Validate discoveries against optional or downloaded references and collect plots. |

## Step resolution

`lib/sieve_helpers.nf` defines `resolveExecuteSteps()`.

If `--execute_step` is unset, the workflow requests all steps:

```text
sex, preprocess, grid, cv, explain, ablation, null, epistasis, validation, plots
```

If `--execute_step all` is supplied, it resolves to the same full set. Individual aliases such as `grid_search`, `cross_validation`, and `discovery_validation` are normalized internally, but the documented stable names are the ten names above.

## Channel flow

The practical flow is:

```text
raw VCF + phenotypes + sex map
          |
          v
PREPROCESS -> preprocessed.pt -> grid search -> best_params.yaml
          |                           |
          v                           v
TRAIN_AND_EXPLAIN -> CV folds -> best checkpoint -> explain real data
          |                                      |
          |                                      +-> validation
          |                                      +-> epistasis
          v
null baseline -> explain null -> compare attributions -> calibrate/correct rankings

ABLATION uses preprocessed data, sex map, best params, and null-preprocessed data
to create per-level real/null training and attribution comparisons.
```

## Published output model

The pipeline uses Nextflow workflow outputs rather than per-process `publishDir` blocks. The publish destinations are declared in the `output {}` block of `main.nf`, with paths such as:

```text
${params.cohort_id}/data
${params.cohort_id}/real_experiments/L3/training
${params.cohort_id}/attribution_comparison/L3
pipeline_info
```

This is why the published tree is grouped by `--cohort_id`.
