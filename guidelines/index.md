# SIEVE Guidelines

This site is the extended documentation layer for `lescailab/sieve`. The repository keeps quick-access documentation in the root [README](https://github.com/lescailab/sieve-nextflow/blob/master/README.md), [usage guide](https://github.com/lescailab/sieve-nextflow/blob/master/docs/usage.md), and [output guide](https://github.com/lescailab/sieve-nextflow/blob/master/docs/output.md); this site explains the same pipeline in a tutorial-style order for users who need to understand how the workflow is assembled and how to operate it safely.

## Documentation layers

| Layer | Audience | Purpose |
| --- | --- | --- |
| `README.md` | First-time users | Run a smoke test, identify minimal inputs, and find the main docs. |
| `docs/usage.md` | Routine users | Check verified parameters, profiles, and common execution patterns. |
| `docs/output.md` | Routine users | Locate published result files. |
| `guidelines/` | Users and maintainers | Understand concepts, configuration, workflow steps, failure modes, and extension points. |

## What the pipeline does

The pipeline takes a bgzipped, indexed, multi-sample VCF plus phenotype data, prepares SIEVE-ready tensors, trains models, selects checkpoints, produces explainability rankings, compares real and null attribution patterns, and can run ablation, epistasis, validation, and plot-collection branches.

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

This documentation is structured around the nf-core expectation that bundled pipeline documentation includes a README, usage guide, and output guide, and around the Nextflow training style of moving from runnable examples to concepts and then advanced configuration.

Reference material:

- [nf-core pipeline specifications](https://nf-co.re/docs/guidelines/pipelines/overview)
- [nf-core bundled documentation requirement](https://nf-co.re/docs/guidelines/pipelines/requirements/documentation)
- [Nextflow training: Hello Nextflow](https://training.nextflow.io/latest/hello_nextflow/)
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
