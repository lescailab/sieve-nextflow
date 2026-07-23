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

## Reuse downstream artifacts

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

Use step selection when you know which upstream channels are needed. The workflow exposes shortcut artifacts for sex maps, preprocessed data, best parameters, and best checkpoints; it does not expose a shortcut for every internal channel.

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
