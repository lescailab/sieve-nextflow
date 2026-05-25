# Reproducibility

Reproducibility comes from pinning the pipeline revision, recording parameters, using containers or fixed environments, and preserving execution reports.

## Pin the pipeline revision

For released versions:

```bash
nextflow run lescailab/sieve-nextflow \
  -r <release> \
  -profile docker,gpu \
  -params-file params.yml
```

For local development, record the Git commit used for the run.

## Use parameter files

Keep run parameters in YAML or JSON:

```yaml
vcf: /path/to/data.vcf.gz
phenotypes: /path/to/phenotypes.tsv
genome_build: GRCh38
cohort_id: cohort_a
outdir: results
train_device: cuda
```

Do not commit real paths or private cohort identifiers. Use local, ignored parameter files for execution-specific values.

## Preserve pipeline info

The pipeline writes:

```text
pipeline_info/params_<timestamp>.json
pipeline_info/nf_core_sieve_software_versions.yml
pipeline_info/execution_trace_<timestamp>.txt
pipeline_info/execution_report_<timestamp>.html
pipeline_info/execution_timeline_<timestamp>.html
pipeline_info/pipeline_dag_<timestamp>.html
```

These files document runtime parameters, software versions, process timing, and task-level execution status.

## Containers and environments

Local modules point to a pinned container image:

```text
ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2
```

Use a container profile for portable execution:

```bash
-profile docker,gpu
```

or:

```bash
-profile apptainer,gpu
```

Conda and Mamba profiles are also defined, but container execution is easier to reproduce across systems when the image is available.

## Randomness

Relevant defaults:

| Parameter | Default |
| --- | --- |
| `--train_seed` | `42` |
| `--null_seed` | `42` |
| `--null_bootstrap` | `1000` |

Keep these values fixed when comparing runs.

## Resume behavior

Nextflow `-resume` can reuse previous task outputs:

```bash
nextflow run lescailab/sieve-nextflow \
  -profile docker,gpu \
  -params-file params.yml \
  -resume
```

Use `-resume` only when the work directory is preserved and the command still describes the same intended analysis.

## Hidden reproducibility risks

- Validation references can be downloaded automatically when none are supplied. For fixed analyses, provide versioned local reference files with `--clinvar_tsv`, `--gwas_tsv`, and `--go_mapping_json`.
- `--publish_dir_mode move` can remove files from work directories. The default is `copy`.
- CPU and GPU training may not produce identical floating-point behavior.
- `--execute_step` can alter which upstream channels are created and therefore which outputs exist.
