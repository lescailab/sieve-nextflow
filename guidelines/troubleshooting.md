# Troubleshooting

This page lists failure modes verified from code paths and the smoke-test run.

## Missing VCF

Error pattern:

```text
Missing required argument: --vcf (required by selected execution steps).
```

Cause: selected steps need sex inference or preprocessing, and no shortcut artefact satisfies that need.

Fix: provide `--vcf`, or provide the relevant shortcut inputs such as `--preprocessed_data` and `--sex_map`.

## Missing VCF index

Error pattern:

```text
Could not find a VCF index for '<vcf>'. Expected '<vcf>.tbi' or '<vcf>.csi'.
```

Fix: create an index beside the bgzipped VCF:

```text
/path/to/data.vcf.gz.tbi
```

or:

```text
/path/to/data.vcf.gz.csi
```

## Sex map required

Error pattern:

```text
The selected execution steps require sex information. Provide --sex_map or set --infer_sex true.
```

Cause: sex information is required, no `--sex_map` was provided, and sex inference is disabled.

Fix:

```bash
--infer_sex true
```

or:

```bash
--infer_sex false --sex_map /path/to/sample_sex.tsv
```

## Checkpoint pair mismatch

Error pattern:

```text
Parameters --best_checkpoint and --checkpoint_config must be provided together.
```

Fix: supply both files or neither.

## Training starts on CUDA unexpectedly

Cause: `--train_device` defaults to `cuda`.

Fix for CPU trials:

```bash
--train_device cpu
```

For GPU runs, combine a container profile with `gpu`:

```bash
-profile docker,gpu
```

## Selected step produces few or no outputs

Cause: `--execute_step` limits the requested branches, but later branches still need upstream data channels.

Fix: either omit `--execute_step` for a full run, include the required upstream steps, or provide shortcut artefacts where available.

When `ablation` is selected, the workflow creates the null-preprocessed dataset even if `null` is absent from `--execute_step`. Adding `null` also runs the full L3 null training, explanation and attribution-comparison branch.

## Profile value warning

The verified smoke command completed but logged:

```text
WARN: nf-core pipelines do not accept positional arguments. The positional argument `test` has been detected.
```

This warning appears to come from the local positional-argument parser in `main.nf`, which tokenizes `workflow.commandLine` and can treat the `-profile` value as positional. The run still completed successfully. The parser should be fixed in code; do not document profile values as positional arguments.

## MkDocs command not found

The local pipeline tooling environment may not include MkDocs. Install Material for MkDocs in a documentation environment:

```bash
pip install mkdocs-material
```

Then run:

```bash
mkdocs serve -f mkdocs.yml
```

## Where to inspect failures

Use:

```text
<outdir>/pipeline_info/execution_trace_<timestamp>.txt
<outdir>/pipeline_info/execution_report_<timestamp>.html
.nextflow.log
work/<task-hash>/.command.err
work/<task-hash>/.command.log
```

For input and parameter errors, check the early log output from `PIPELINE_INITIALISATION`.
