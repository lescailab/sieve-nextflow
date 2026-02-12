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

These are available but intentionally not required for quickstart usage:

- `--cv_folds` (default `5`)
- `--val_split` (default `0.2`)
- `--null_seed` (default `42`)
- Optional validation resources:
  - `--clinvar_tsv`
  - `--gwas_tsv`
  - `--go_mapping_json`

The internal hyperparameter grid is configured in `nextflow.config` and can be overridden with params files if needed.

## Reproducibility

Use versioned pipeline releases:

```bash
nextflow run nf-core/sieve -r <release> ...
```

Reuse fixed parameter sets via `-params-file` (`YAML` or `JSON`) for reproducible reruns.
