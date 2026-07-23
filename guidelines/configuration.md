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
| `--cv_folds` | `5` | CV folds for `SIEVE_TRAIN_CV`. |
| `--train_device` | `cuda` | Passed to SIEVE training. |
| `--publish_dir_mode` | `copy` | Sets `workflow.output.mode`. |

## Training parameters

Types, defaults and base descriptions in these tables come from `nextflow_schema.json`.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `--train_aggregation_method` | string | `mean` | Aggregation method passed to SIEVE training. |
| `--train_chunk_overlap` | integer | `0` | Overlap between adjacent chunks (forwarded to `sieve-train --chunk-overlap`). |
| `--train_class_weighting` | string | `auto` | Inverse-frequency class weighting strategy (forwarded to `sieve-train --class-weighting`). |
| `--train_classifier_type` | string or null | Not set | Optional classifier-head architecture (forwarded to `sieve-train --classifier-type`). When null, the SIEVE default is used. |
| `--train_early_stopping` | integer | `10` | Early stopping patience for training runs. |
| `--train_gradient_accumulation_steps` | integer | `4` | Gradient accumulation steps for all training stages. |
| `--train_gradient_clip` | number | `1.0` | Gradient clipping threshold for all training stages. |
| `--train_hidden_dim` | integer | `64` | Default hidden dimension used across training stages. |
| `--train_num_attention_layers` | integer | `1` | Default number of attention layers used across training stages. |
| `--train_num_heads` | integer or null | Not set | Optional fixed number of attention heads (forwarded to `sieve-train --num-heads`). |

The `flatten` classifier head is the SIEVE default and the head used throughout this pipeline. `attention_pool` is available as an alternative and underperformed on the cohorts tested; use the framework [command reference for `sieve-train`](https://lescailab.github.io/sieve-project/command-reference/#trainpy) for its CLI contract.

## Explainability parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `--explain_aggregation_method` | string or null | Not set | Score aggregation method used by `sieve-explain` (`--aggregation-method`). |
| `--explain_attention_percentile` | number or null | Not set | Percentile cutoff when `--explain_attention_threshold_mode` is `percentile` (`--attention-percentile`). |
| `--explain_attention_threshold` | number or null | Not set | Minimum attention weight to keep an interaction (`--attention-threshold`). |
| `--explain_attention_threshold_mode` | string or null | Not set | Attention threshold mode (`--attention-threshold-mode`). |
| `--explain_batch_size` | integer or null | Not set | Dataloader batch size for `sieve-explain` (`--batch-size`). |
| `--explain_max_variants` | integer or null | Not set | Maximum variants per sample considered during integrated-gradients computation (`--max-variants`). |
| `--explain_n_steps` | integer or null | Not set | Integration steps for integrated-gradients in `sieve-explain` (`--n-steps`). |
| `--explain_skip_attention` | boolean | `false` | Skip attention analysis in `sieve-explain` (`--skip-attention`). |
| `--explain_skip_ig` | boolean | `false` | Skip integrated-gradients computation in `sieve-explain` (`--skip-ig`). |
| `--explain_top_k_interactions` | integer or null | Not set | Number of top interactions extracted by `sieve-explain` (`--top-k-interactions`). |
| `--explain_top_k_variants` | integer or null | Not set | Number of top variants extracted by `sieve-explain` (`--top-k-variants`). |

See the framework [command reference for `sieve-explain`](https://lescailab.github.io/sieve-project/command-reference/#explainpy) for the scientific and CLI context behind these controls.

## Covariate and chromosome parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `--pc_map` | string or null | Not set | Optional TSV with `sample_id`, `PC1`, `PC2`, ... for population-structure adjustment. Shared between `sieve-train` and `sieve-explain`. |
| `--num_pcs` | integer | `0` | Number of principal components from `--pc_map` to use as covariates. |
| `--chrx_include_sex_chroms` | boolean | `false` | Include sex chromosomes in the corrected output of `sieve-correct-chrx-bias` (`--include-sex-chroms`). |
| `--compare_exclude_sex_chroms` | boolean | `false` | Drop sex-chromosome variants in `sieve-compare-attributions` (`--exclude-sex-chroms`). |

`--pc_map` and `--num_pcs` supply population-structure covariates to training and explanation. The framework [command reference](https://lescailab.github.io/sieve-project/command-reference/) describes how those covariates enter the model.

Generic nf-core-derived options such as `--email`, `--help`, `--version`, `--monochrome_logs` and the `--config_profile_*` family behave as in other nf-core-derived pipelines and are listed in `nextflow_schema.json`.

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
