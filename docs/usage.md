# lescailab/sieve: Usage

This page lists the verified command-line interface exposed by `main.nf`, `nextflow.config`, `nextflow_schema.json`, and the SIEVE argument validator. For a deeper walk-through, see the [guidelines](../guidelines/running-the-pipeline.md).

## Execution entry point

Run the pipeline with `nextflow run lescailab/sieve-nextflow` or, from a local checkout, `nextflow run .`.

Verified smoke test:

```bash
nextflow run . \
  -profile test \
  -stub-run \
  --outdir results_stub
```

## Required inputs

The required inputs depend on the selected steps and any shortcut artefacts you provide.

Raw-input mode requires:

| Parameter | Requirement |
| --- | --- |
| `--vcf` | Existing `.vcf.gz` file with matching `.vcf.gz.tbi` or `.vcf.gz.csi` index. |
| `--phenotypes` | Existing tab-separated file: two columns (sample ID, integer label `1` or `2`), no header row. The Nextflow layer checks only that the file exists; detailed parsing is performed by `sieve-preprocess`. |
| `--genome_build` | `GRCh37` or `GRCh38`. Default: `GRCh38`. |
| `--sex_map` or `--infer_sex true` | If `--sex_map` is absent, the pipeline must infer sex from `--vcf`. If `--infer_sex false`, `--sex_map` is required. |

Example raw-input command:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --outdir results
```

## Sex handling

Default behaviour:

```bash
--infer_sex true
```

Provide recorded sex metadata only for concordance checking during sex inference:

```bash
--known_sex /path/to/known_sex.tsv
```

Skip sex inference with a prepared sex map:

```bash
--infer_sex false --sex_map /path/to/sample_sex.tsv
```

If both `--sex_map` and `--infer_sex true` are supplied, the pipeline uses `--sex_map` and logs a warning.

## Artefact shortcuts

These inputs skip upstream work when the selected steps can be satisfied from existing files:

| Parameter | Expected file | Effect |
| --- | --- | --- |
| `--preprocessed_data` | `.pt` | Skips VCF preprocessing. |
| `--best_params` | `.yaml` or `.yml` | Skips internal hyperparameter grid search. |
| `--best_checkpoint` with `--checkpoint_config` | `.pt` plus `.yaml` or `.yml` | Skips CV checkpoint training and selection. Both parameters are required together. |

Example using downstream artefacts:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  --preprocessed_data /path/to/preprocessed.pt \
  --sex_map /path/to/sample_sex.tsv \
  --best_checkpoint /path/to/best_model.pt \
  --checkpoint_config /path/to/config.yaml \
  --outdir results
```

## Step selection

By default, `--execute_step` is unset and the pipeline requests all defined steps:

```text
sex, preprocess, grid, cv, explain, ablation, null, epistasis, validation, plots
```

Limit execution with a comma-separated list:

```bash
--execute_step explain,null,validation
```

Allowed step names are:

- `sex`
- `preprocess`
- `grid`
- `cv`
- `explain`
- `ablation`
- `null`
- `epistasis`
- `validation`
- `plots`

Later steps still need their upstream data channels. If you omit upstream steps, provide the corresponding shortcut artefacts where the pipeline exposes them. See [workflow steps](../guidelines/workflow-steps.md) for the dependency map.

**`ablation` note:** selecting `ablation` automatically triggers null-baseline dataset creation (`SIEVE_CREATE_NULL_BASELINE`) so that per-level null comparisons always run. Adding `null` to the step list additionally runs the full L3 null training and attribution comparison.

## Profiles

Common profiles defined in `nextflow.config`:

| Profile | Purpose |
| --- | --- |
| `test` | Bundled minimal test data from `conf/test.config`. |
| `test_full` | Includes `conf/test_full.config`, currently mirroring `test`. |
| `docker` | Run processes in Docker containers. |
| `singularity` / `apptainer` | Run processes with Singularity or Apptainer. |
| `conda` / `mamba` | Build module Conda environments. |
| `gpu` | Adds GPU runtime options and process accelerators for GPU-capable profiles. |
| `wave` | Enables Wave with frozen conda/container strategy. |
| `google_batch_a100_no_fusion` | Google Batch executor with A100 GPU machines; standard GCS file staging (Fusion disabled). Combine with `docker,gpu`. |
| `debug` | Enables additional process-name validation and debug settings. |

Combine profiles with commas:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --outdir results
```

## Advanced parameters

Training defaults are configured in `nextflow.config` and exposed in `nextflow_schema.json`. The most commonly adjusted values are:

| Parameter | Default |
| --- | --- |
| `--cohort_id` | `cohort` |
| `--default_train_level` | `L3` |
| `--cv_folds` | `5` |
| `--val_split` | `0.2` |
| `--train_device` | `cuda` |
| `--train_epochs` | `100` |
| `--train_batch_size` | `16` |
| `--train_chunk_size` | `3000` |
| `--null_seed` | `42` |
| `--null_bootstrap` | `1000` |

The internal grid-search parameters are:

- `--grid_lr`
- `--grid_lambda_attr`
- `--grid_latent_dim`
- `--grid_hidden_dim`
- `--grid_num_attention_layers`

Optional validation resources:

- `--clinvar_tsv`
- `--gwas_tsv`
- `--go_mapping_json`

If none of the validation resources are supplied and `validation` is selected, the workflow runs the reference-download module to fetch all three. If any subset is supplied, the missing resources are omitted rather than downloaded; partial downloads are not triggered.

## Parameter files

Use a YAML or JSON parameter file for repeatable runs:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  -params-file params.yml
```

Keep dataset-specific paths in local parameter files or execution commands, not in committed documentation.
