# Configuration

SIEVE follows the standard Nextflow configuration model: base defaults are declared in `nextflow.config`, included config files add resource and module behaviour, profiles override runtime settings, and command-line parameters have the final say.

## Configuration files

| File | Role |
| --- | --- |
| `nextflow.config` | Default parameters, profiles, manifest, reports, environment variables, plugin declaration, and included configs. |
| `conf/base.config` | Process resource defaults and labels. |
| `conf/modules.config` | Module-specific process options. Currently configures compare-attribution genome-build arguments. |
| `conf/test.config` | Bundled test data and smaller grid for test runs. |
| `conf/test_full.config` | Full-test profile wrapper; currently includes `test.config`. |
| `conf/google_batch_a100_no_fusion.config` | Google Batch executor with A100 GPU and standard GCS staging (no Fusion). |
| `nextflow_schema.json` | Parameter schema for validation and help text. |

## Core defaults

Important defaults from `nextflow.config`:

| Parameter | Default | Notes |
| --- | --- | --- |
| `--outdir` | `results` | Root publish directory. |
| `--cohort_id` | `cohort` | Published under `<outdir>/<cohort_id>/`. |
| `--genome_build` | `GRCh38` | Allowed values: `GRCh37`, `GRCh38`. |
| `--infer_sex` | `true` | Used when sex information is needed and no `--sex_map` is supplied. |
| `--default_train_level` | `L3` | Main training level. |
| `--cv_folds` | `5` | CV folds for `SIEVE_TRAIN_CV`; use `1` for the single-training path described under [Execution modes](running-the-pipeline.md#execution-modes). The schema permits `0`, but the current workflow falls back to five folds for that value. |
| `--train_device` | `cuda` | Passed to SIEVE training. |
| `--publish_dir_mode` | `copy` | Sets `workflow.output.mode`. |

## Resource labels

`conf/base.config` defines labels used by modules:

| Label | Default resources |
| --- | --- |
| `process_single` | 1 CPU, 6 GB memory, 12 h |
| `process_low` | 2 CPUs, 24 GB memory, 24 h |
| `process_medium` | 6 CPUs, 72 GB memory, 48 h |
| `process_high` | 12 CPUs, 128 GB memory, 72 h |
| `process_long` | 120 h |
| `process_high_memory` | 256 GB memory |
| `process_gpu` | 72 h per attempt, optional accelerator when profile contains `gpu` |

The defaults scale with task attempts where configured.

## Profiles

Profiles are selected with `-profile`, not with `--profile`:

```bash
nextflow run . -profile test -stub-run --outdir results_stub
```

Combine profiles with commas:

```bash
nextflow run . -profile docker,gpu -params-file params.yml
```

## Reports

Nextflow reports are enabled by default:

```text
pipeline_info/execution_timeline_<timestamp>.html
pipeline_info/execution_report_<timestamp>.html
pipeline_info/execution_trace_<timestamp>.txt
pipeline_info/pipeline_dag_<timestamp>.html
pipeline_info/params_<timestamp>.json
pipeline_info/nf_core_sieve_software_versions.yml
```

The suffix is controlled by `--trace_report_suffix`.

## Custom configs

The root config includes nf-core custom config support through `params.custom_config_base`. For offline or tightly controlled runs, check whether your environment should set `NXF_OFFLINE=true` or pass a local custom config.

## Command-line precedence

Use command-line values for short-lived overrides:

```bash
nextflow run . \
  -profile docker \
  --train_device cpu \
  --outdir results_cpu
```

Use `-params-file` for repeatable runs:

```bash
nextflow run . \
  -profile docker,gpu \
  -params-file params.yml
```
