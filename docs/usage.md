# nf-core/sieve: Usage

## Required inputs

Run with the following required parameters:

- `--vcf`: bgzipped indexed multi-sample VCF (`.vcf.gz` + `.tbi` or `.csi`)
- `--phenotypes`: TSV with columns `sample_id` and `phenotype`
- `--genome_build`: `GRCh37` or `GRCh38`
- `--outdir`: output directory

Minimal command:

```bash
nextflow run nf-core/sieve \
  -profile docker \
  --vcf cohort.vcf.gz \
  --phenotypes phenotypes.tsv \
  --genome_build GRCh38 \
  --outdir results
```

`phenotypes.tsv` example:

```tsv
sample_id	phenotype
sampleA	case
sampleB	control
```

## Sex handling

Default behavior is sex inference:

```bash
--infer_sex true
```

To skip inference, provide a sex map:

```bash
--infer_sex false --sex_map sample_sex.tsv
```

If `--sex_map` is provided, it is used and inference is skipped.

## Profiles

Generic software profiles:

- `docker`
- `singularity`
- `apptainer`
- `conda`
- `test`
- `test_full`

Recommended quick validation:

```bash
nextflow run nf-core/sieve -profile test -stub-run --outdir test_results
```

## Advanced options

### Pipeline-wide training defaults

The following parameters are applied pipeline-wide across grid search, CV, ablation, and null-model training:

- `--cv_folds` (default `5`)
- `--val_split` (default `0.2`)
- `--null_seed` (default `42`)
- `--train_epochs` (default `100`)
- `--train_batch_size` (default `16`)
- `--train_chunk_size` (default `3000`)
- `--train_aggregation_method` (default `mean`)
- `--train_gradient_accumulation_steps` (default `4`)
- `--train_gradient_clip` (default `1.0`)
- `--train_seed` (default `42`)
- `--train_device` (default `cuda`)
- `--train_early_stopping` (default `10`)
- `--train_hidden_dim` (default `64`)
- `--train_num_attention_layers` (default `1`)

Memory impact notes:

- `train_batch_size` and `train_chunk_size` have the strongest effect on GPU memory usage.
- These values are fixed pipeline-wide by default and are intentionally not expanded in the optimization grid.

### Hyperparameter search grid

The internal search grid focuses on:

- `--lr` via `--grid_lr` (default `[0.00001, 0.0001]`)
- `--lambda-attr` via `--grid_lambda_attr` (default `[0.01, 0.1, 0.5, 1.0]`)
- `--latent-dim` via `--grid_latent_dim` (default `[32, 64]`)
- `--hidden-dim` via `--grid_hidden_dim` (default `[64, 128]`)
- `--num-attention-layers` via `--grid_num_attention_layers` (default `[1, 2]`)

`hidden` and `layers` are intentionally restricted to a small range around the base defaults.

Example override:

```bash
nextflow run nf-core/sieve \
  -profile docker \
  --vcf cohort.vcf.gz \
  --phenotypes phenotypes.tsv \
  --genome_build GRCh38 \
  --grid_lr 0.00001,0.0001 \
  --grid_lambda_attr 0.1,0.5 \
  --grid_latent_dim 32,64 \
  --train_batch_size 16 \
  --train_chunk_size 3000 \
  --train_device cpu \
  --outdir results
```

### Optional validation resources

- `--clinvar_tsv`
- `--gwas_tsv`
- `--go_mapping_json`

## Reproducibility

Use versioned pipeline releases:

```bash
nextflow run nf-core/sieve -r <release> ...
```

Reuse fixed parameter sets via `-params-file` (`YAML` or `JSON`) for reproducible reruns.
