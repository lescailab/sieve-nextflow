# Inputs

This page distinguishes required raw inputs from optional shortcut artifacts.

## Raw inputs

| Input | Parameter | Verified checks in the Nextflow layer |
| --- | --- | --- |
| Multi-sample VCF | `--vcf` | File exists, ends with `.vcf.gz`, and has `.tbi` or `.csi` sibling index. |
| Phenotype TSV | `--phenotypes` | File exists. Detailed format validation is delegated to `sieve-preprocess`. |
| Genome build | `--genome_build` | Must be `GRCh37` or `GRCh38`. Default: `GRCh38`. |
| Sex metadata | `--sex_map` or `--infer_sex true` | If selected steps need sex information and no sex map is supplied, sex inference must be enabled. |

Phenotype TSV format (confirmed from bundled test data and SIEVE CLI contract):

```text
sample1	2
sample2	1
```

Two tab-separated columns, no header row. Column 1 is the sample identifier; column 2 is an integer class label (`1` or `2`). The Nextflow layer checks only that the file exists; detailed parsing and validation are delegated to the `sieve-preprocess` CLI.

## VCF index naming

For:

```text
/path/to/data.vcf.gz
```

the validator accepts either:

```text
/path/to/data.vcf.gz.tbi
/path/to/data.vcf.gz.csi
```

## Sex-map inputs

The effective sex map is published as:

```text
<outdir>/<cohort_id>/data/sample_sex.tsv
```

If `--sex_map` is supplied, `SIEVE_EMIT_SEX_MAP` copies it into that standardized filename. If `--sex_map` is absent and sex information is needed, `SIEVE_INFER_SEX` calls:

```text
sieve-infer-sex --vcf <vcf> --output-dir infer_sex_diagnostics --genome-build <build>
```

`--known_sex` is only passed to sex inference for concordance checking. It does not replace `--sex_map`.

## Shortcut artifacts

| Artifact | Parameter | Format check | Used to skip |
| --- | --- | --- | --- |
| Preprocessed tensor | `--preprocessed_data` | Existing `.pt` | VCF preprocessing |
| Best parameter file | `--best_params` | Existing `.yaml` or `.yml` | Grid search |
| Best checkpoint | `--best_checkpoint` | Existing `.pt` | CV checkpoint training and selection |
| Checkpoint config | `--checkpoint_config` | Existing `.yaml` or `.yml` | Required with `--best_checkpoint` |

The validator rejects `--best_checkpoint` without `--checkpoint_config`, and rejects `--checkpoint_config` without `--best_checkpoint`.

## Optional validation resources

These are used only when `validation` is selected:

- `--clinvar_tsv`
- `--gwas_tsv`
- `--go_mapping_json`

If none are supplied, the workflow runs `SIEVE_DOWNLOAD_REFERENCES` to fetch all three. If any subset is supplied, the missing ones are represented internally as absent (not downloaded). The workflow does not perform partial downloads when at least one reference is already provided.

## Input privacy

Keep real dataset paths, cohort identifiers, and phenotype labels out of committed files. Use placeholders in shared documentation and local parameter files for execution.
