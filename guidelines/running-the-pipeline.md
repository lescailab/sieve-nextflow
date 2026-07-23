# Running the Pipeline

This page collects runnable command patterns. Use placeholder paths and keep real dataset identifiers in local shell commands or parameter files.

## Smoke test

```bash
nextflow run . \
  -profile test \
  -stub-run \
  --outdir results_stub
```

This command was verified against the current repository. It exercises the complete graph with stub outputs.

## Full raw-input run

```bash
nextflow run lescailab/sieve-nextflow \
  -r dev \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --outdir results
```

Use `--genome_build GRCh37` for GRCh37 data.

## Execution modes

The grid and CV settings determine which training processes run:

| Mode | Trigger | Processes | Published training output |
| --- | --- | --- | --- |
| Grid search with cross-validation | Leave `--train_lr`, `--train_lambda_attr` and `--train_latent_dim` unset, and use `--cv_folds` greater than `1`. This is the default. | `SIEVE_TRAIN_SINGLE_GRID` and `SIEVE_SELECT_BEST_PARAMS` resolve the parameter grid. `SIEVE_TRAIN_CV` and `SIEVE_SELECT_BEST_CHECKPOINT` then run. | `real_experiments/L3/cross_fold/cv_output/fold_*/` plus `real_experiments/L3/training/best_checkpoint.pt`, `best_fold_config.yaml` and `cv_folds_summary.tsv`. |
| Fixed hyperparameters with cross-validation | Supply all three of `--train_lr`, `--train_lambda_attr` and `--train_latent_dim`, and use `--cv_folds` greater than `1`. | `SIEVE_EMIT_BEST_PARAMS` materialises the fixed map as `best_params.yaml`, bypassing `SIEVE_TRAIN_SINGLE_GRID` and `SIEVE_SELECT_BEST_PARAMS`. CV and checkpoint selection still run. | The same cross-fold and selected-checkpoint files as the default mode. The intermediate `best_params.yaml` remains a workflow input rather than a separately published result. |
| Fixed hyperparameters with one training run | Supply all three fixed parameters and set `--cv_folds 1`. | `SIEVE_EMIT_BEST_PARAMS` resolves the parameters and `SIEVE_TRAIN_SINGLE_MAIN` trains once with `--val_split`. Grid search, `SIEVE_TRAIN_CV` and `SIEVE_SELECT_BEST_CHECKPOINT` are skipped. | `real_experiments/L3/training/best_model.pt`, `config.yaml` and `results.yaml`. No `cross_fold/` output is published. |

Use `--cv_folds 1` to select the single-training branch after the parameter source is resolved. `nextflow_schema.json` also permits `0`, but the current workflow expression treats `0` as false and falls back to the default five folds. If you omit the fixed trio and do not supply `--best_params`, the pipeline can still run the grid first and then perform one final training run.

## Provide a sex map

```bash
nextflow run lescailab/sieve-nextflow \
  -r dev \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --infer_sex false \
  --sex_map /path/to/sample_sex.tsv \
  --outdir results
```

Why: this skips `sieve-infer-sex` and publishes the supplied map as the effective `sample_sex.tsv`.

## Reuse downstream artefacts

```bash
nextflow run lescailab/sieve-nextflow \
  -r dev \
  -profile docker,gpu \
  --preprocessed_data /path/to/preprocessed.pt \
  --sex_map /path/to/sample_sex.tsv \
  --best_checkpoint /path/to/best_model.pt \
  --checkpoint_config /path/to/config.yaml \
  --outdir results
```

Why: this avoids raw VCF preprocessing and CV checkpoint selection. The checkpoint config also supplies best-parameter information to branches that need training parameters when `--best_params` is not supplied.

## Limit execution

```bash
nextflow run lescailab/sieve-nextflow \
  -r dev \
  -profile docker,gpu \
  --preprocessed_data /path/to/preprocessed.pt \
  --sex_map /path/to/sample_sex.tsv \
  --best_checkpoint /path/to/best_model.pt \
  --checkpoint_config /path/to/config.yaml \
  --execute_step explain,null,validation \
  --outdir results
```

Use step selection when you know which upstream channels are needed. The workflow exposes shortcut artefacts for sex maps, preprocessed data, best parameters, and best checkpoints; it does not expose a shortcut for every internal channel.

## Use a parameter file

`params.yml`:

```yaml
vcf: /path/to/data.vcf.gz
phenotypes: /path/to/phenotypes.tsv
genome_build: GRCh38
outdir: results
cohort_id: cohort_a
train_device: cuda
```

Command:

```bash
nextflow run lescailab/sieve-nextflow \
  -r dev \
  -profile docker,gpu \
  -params-file params.yml
```

Parameter files are the preferred way to make a run repeatable without committing real paths to the repository.

## Resume interrupted work

Use Nextflow resume when the command and work directory are still valid:

```bash
nextflow run lescailab/sieve-nextflow \
  -r dev \
  -profile docker,gpu \
  -params-file params.yml \
  -resume
```

`-resume` reuses cached tasks when inputs, scripts, and relevant parameters match.
