<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/lescailab-sieve_logo_dark.png">
    <img alt="lescailab/sieve" src="assets/lescailab-sieve_logo_light.png">
  </picture>
</h1>

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/lescailab/sieve-nextflow)
[![GitHub Actions CI Status](https://github.com/lescailab/sieve-nextflow/actions/workflows/nf-test.yml/badge.svg)](https://github.com/lescailab/sieve-nextflow/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/lescailab/sieve-nextflow/actions/workflows/linting.yml/badge.svg)](https://github.com/lescailab/sieve-nextflow/actions/workflows/linting.yml)
[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/sieve/results)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.5.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.5.2)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**lescailab/sieve** runs a SIEVE workflow for case-control variant discovery from a bgzipped, indexed, multi-sample VCF. It prepares or ingests sex metadata, preprocesses variants and phenotypes, trains and selects models, generates explainability outputs, compares real and null attributions, and can run ablation, epistasis, validation, and plot-collection steps.

## Quick start

Run a local smoke test with bundled data and stubbed process scripts:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile test \
  -stub-run \
  --outdir results_stub
```

From a local checkout, replace `lescailab/sieve-nextflow` with `.`.

## Minimal inputs

For a raw-input analysis, provide:

- `--vcf`: bgzipped multi-sample VCF ending in `.vcf.gz`, with a sibling `.tbi` or `.csi` index
- `--phenotypes`: phenotype TSV accepted by `sieve-preprocess`
- `--genome_build`: `GRCh37` or `GRCh38`
- sex metadata, either inferred from the VCF with the default `--infer_sex true`, or supplied with `--sex_map`

## Example command

The training steps use `--train_device cuda` by default. Use a GPU-enabled profile for production runs, or override the training device deliberately.

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --outdir results
```

## Documentation

- [Usage](docs/usage.md): verified parameters, profiles, and common execution patterns
- [Output](docs/output.md): published output directories and key files
- [Guidelines](guidelines/index.md): in-depth MkDocs Material documentation for concepts, workflow steps, troubleshooting, and extension work

## Credits

lescailab/sieve was originally written by Francesco Lescai.

## Contributions and support

See the [contributing guidelines](.github/CONTRIBUTING.md). For help, use the [nf-core Slack `#sieve` channel](https://nfcore.slack.com/channels/sieve) after joining via [nf-co.re/join/slack](https://nf-co.re/join/slack).

## Citations

References for SIEVE, nf-core, Nextflow, and packaging/container tooling are listed in [CITATIONS.md](CITATIONS.md).
