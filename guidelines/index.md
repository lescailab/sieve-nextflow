# SIEVE Nextflow

!!! warning "Development status"

    This pipeline is under active development on the `dev` branch and has no tagged release. Parameters, output paths and default values can change between commits. Pin a commit when you need a reproducible run, as described in [Reproducibility](reproducibility.md).

This site documents the Nextflow pipeline that orchestrates SIEVE. The scientific method, the model, the encoding, the explainability procedures and the command-line tools live in [`lescailab/sieve-project`](https://github.com/lescailab/sieve-project), documented at [SIEVE Documentation](https://lescailab.github.io/sieve-project). This repository wraps those tools in a reproducible workflow: it manages inputs, provisions containers, schedules the steps in dependency order, handles resource allocation and retries, and publishes results in a fixed layout. Read the framework documentation to understand what each step computes. Read this site to understand how to run the steps together.

The repository also keeps quick-access documentation in the root [README](https://github.com/lescailab/sieve-nextflow/blob/dev/README.md), [usage guide](https://github.com/lescailab/sieve-nextflow/blob/dev/docs/usage.md), and [output guide](https://github.com/lescailab/sieve-nextflow/blob/dev/docs/output.md).

## Documentation layers

| Layer | Audience | Purpose |
| --- | --- | --- |
| `README.md` | First-time users | Run a smoke test, identify minimal inputs, and find the main docs. |
| `docs/usage.md` | Routine users | Check verified parameters, profiles, and common execution patterns. |
| `docs/output.md` | Routine users | Locate published result files. |
| `guidelines/` | Users and maintainers | Understand concepts, configuration, workflow steps, failure modes, and extension points. |

## What the pipeline does

The pipeline takes a bgzipped, indexed, multi-sample VCF plus phenotype data, prepares SIEVE-ready tensors, trains models, selects checkpoints, produces explainability rankings, compares real and null attribution patterns, and can run ablation, candidate-interaction testing with power analysis, validation, and plot-collection branches.

The default execution requests all defined steps:

```text
sex -> preprocess -> grid -> cv -> explain
                       |       |
                       |       +-> null -> attribution comparison
                       |
                       +-> ablation -> per-level attribution comparison
explain + preprocess -> epistasis
explain + references  -> validation
all plot sources      -> plots
```

## Verified facts

- Entry point: `main.nf`
- Named workflow: `NFCORE_SIEVE`, which calls `workflows/sieve.nf`
- Primary workflow: `SIEVE`
- Minimum Nextflow version in the manifest: `>=25.04.0`
- Parameter schema: `nextflow_schema.json`
- Runtime plugin: `nf-schema@2.5.1`
- Main config: `nextflow.config`
- Module-specific config: `conf/modules.config`
- Resource defaults: `conf/base.config`
- Test profile: `conf/test.config`
- Verified smoke command:

```bash
nextflow run . \
  -profile test \
  -stub-run \
  --outdir results_stub
```

## How to use this site

Start with [Getting started](getting-started.md) if you need to run the pipeline. Use [Pipeline overview](pipeline-overview.md) and [Workflow steps](workflow-steps.md) to understand execution logic. Use [Configuration](configuration.md), [Troubleshooting](troubleshooting.md), and [Reproducibility](reproducibility.md) when moving from test data to a controlled analysis run.

## Standards followed

This pipeline follows nf-core structural conventions without being an nf-core pipeline. Its documentation is structured around the nf-core expectation that bundled pipeline documentation includes a README, usage guide, and output guide, and around the Nextflow training style of moving from runnable examples to concepts and then advanced configuration.

Reference material:

- [nf-core pipeline specifications](https://nf-co.re/docs/guidelines/pipelines/overview)
- [nf-core bundled documentation requirement](https://nf-co.re/docs/guidelines/pipelines/requirements/documentation)
- [Nextflow training: Hello Nextflow](https://training.nextflow.io/latest/hello_nextflow/)
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
