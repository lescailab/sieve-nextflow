# Getting Started

This page takes the shortest path from a clean checkout to a verified pipeline launch.

## 1. Check the software entry point

The pipeline entry point is `main.nf`. From the repository root, use:

```bash
nextflow run .
```

From outside the checkout, use the repository name:

```bash
nextflow run lescailab/sieve-nextflow
```

## 2. Run a smoke test

Use bundled test data and stubbed commands:

```bash
nextflow run . \
  -profile test \
  -stub-run \
  --outdir results_stub
```

Why this is useful:

- `-profile test` supplies small VCF, phenotype, sex-map, and validation-resource test files from `conf/test.config`.
- `-stub-run` exercises the workflow graph without running the real SIEVE command-line tools.
- The command verifies that the Nextflow entry point, configuration, process graph, and publish layout are coherent.

## 3. Inspect the output

The smoke test publishes:

```text
results_stub/
├── cohort/
│   ├── data/
│   ├── real_experiments/
│   ├── null_baselines/
│   ├── attribution_comparison/
│   ├── ablation/
│   ├── epistasis/
│   └── validation/
└── pipeline_info/
```

The default cohort directory is `cohort`. Override it with `--cohort_id`, using a generic identifier such as `cohort_a`.

## 4. Prepare real inputs

For raw-input mode, prepare:

- A bgzipped multi-sample VCF: `/path/to/data.vcf.gz`
- A VCF index beside it: `/path/to/data.vcf.gz.tbi` or `/path/to/data.vcf.gz.csi`
- A phenotype TSV accepted by `sieve-preprocess`
- A genome build: `GRCh37` or `GRCh38`
- Either a sex map or enough VCF information for sex inference

The Nextflow layer validates the VCF extension, the index, file existence, and the genome-build value. It does not validate phenotype columns; malformed phenotype files fail inside `sieve-preprocess`.

## 5. Run a real analysis

The default training device is CUDA. For a GPU run with Docker:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --outdir results
```

For a CPU trial, override the SIEVE training device explicitly:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --train_device cpu \
  --outdir results
```

CPU runs are expected to be slower for training-heavy steps.

## 6. Read the concise docs

Use the root docs for quick reference:

- [README](https://github.com/lescailab/sieve-nextflow/blob/master/README.md)
- [Usage](https://github.com/lescailab/sieve-nextflow/blob/master/docs/usage.md)
- [Output](https://github.com/lescailab/sieve-nextflow/blob/master/docs/output.md)
