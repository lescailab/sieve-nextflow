# Installation

The pipeline can run with containers, Conda/Mamba environments, or software already available on the execution host. Containers are the most reproducible route for normal users.

## Required runtime

The pipeline manifest declares:

```text
nextflowVersion = !>=25.04.0
```

Install a compatible Nextflow release before running the pipeline. The verified local smoke test used Nextflow 25.10.3.

## Nextflow plugin

`nextflow.config` enables:

```groovy
plugins {
    id 'nf-schema@2.5.1'
}
```

The plugin validates parameters against `nextflow_schema.json` and renders the help text.

## Software dependencies

Local SIEVE modules define both:

- `conda "${moduleDir}/environment.yml"`
- a container image pinned as `ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2`

Use one of the software profiles:

```bash
-profile docker
-profile singularity
-profile apptainer
-profile conda
-profile mamba
```

Training-heavy modules are labelled `process_gpu`. The `gpu` profile adds GPU runtime options and sets accelerators for GPU-aware execution.

## GPU expectation

The pipeline default is:

```text
--train_device cuda
```

For GPU container runs:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --outdir results
```

For CPU trials:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --train_device cpu \
  --outdir results
```

## Repository maintenance environment

In this repository, Nextflow-related tooling is expected to run through the Conda environment named `nf-core_3.5.2`:

```bash
conda run -n nf-core_3.5.2 nextflow run . -profile test -stub-run --outdir results_stub
conda run -n nf-core_3.5.2 nf-test test
conda run -n nf-core_3.5.2 nf-core pipelines lint
```

This is a contributor/development convention, not a requirement for external users who already have a compatible Nextflow installation.

## Building these guidelines

The guidelines use Material for MkDocs. Install it in a documentation environment:

```bash
pip install mkdocs-material
```

Preview the site from the repository root:

```bash
mkdocs serve -f guidelines/mkdocs.yml
```

The local `nf-core_3.5.2` environment used for pipeline tooling does not currently provide `mkdocs`.
