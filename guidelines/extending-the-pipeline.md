# Extending the Pipeline

This page is for maintainers adding or changing workflow behavior.

## Follow the existing structure

Current structure:

```text
main.nf
workflows/sieve.nf
subworkflows/local/
modules/local/sieve/
conf/
tests/
docs/
guidelines/
```

Add workflow composition in `subworkflows/local/` and single-command wrappers in `modules/local/sieve/`.

## Keep modules focused

Existing local modules wrap one SIEVE command or one small Python helper. Match that pattern:

- One process per tool command or helper.
- Inputs and outputs declared explicitly.
- `conda` and `container` directives present.
- `stub:` block produces representative output files.
- Versions emitted through `topic: versions` or `versions.yml`.

## Update configuration

When adding a parameter:

1. Add the default to `nextflow.config`.
2. Add validation and help text to `nextflow_schema.json`.
3. Add validation logic to `lib/sieve_helpers.nf` only if Nextflow must catch the error before a process runs.
4. Document the parameter in `docs/usage.md` only if it is user-facing.
5. Add deeper explanation in `guidelines/` when needed.

## Update publishing

Published results are controlled in `main.nf`:

```groovy
publish:
...

output {
    ...
}
```

If a new output is user-facing, add it to:

- `docs/output.md` for concise location and meaning
- `guidelines/outputs-detailed.md` for detailed context

## Test changes

Use repository tooling through the expected Conda environment:

```bash
conda run -n nf-core_3.5.2 nextflow run . -profile test -stub-run --outdir results_stub
conda run -n nf-core_3.5.2 nf-test test
conda run -n nf-core_3.5.2 nf-core pipelines lint
```

Broaden tests when changing shared channels, `--execute_step` behavior, or output publishing.

## Documentation rules

Keep the two-layer strategy:

- README, `docs/usage.md`, and `docs/output.md` stay concise and immediately actionable.
- `guidelines/` carries tutorials, conceptual explanation, assumptions, and troubleshooting.

Do not duplicate long explanations between layers. Link from concise docs to the relevant guidelines page.

## Privacy rule

Never commit real dataset paths, cohort names, server names, or phenotype labels in examples. Use placeholders:

```text
/path/to/data.vcf.gz
cohort_a
phenotype_x
your_server
```

Before staging documentation or tests, scan for real paths and identifiers.
