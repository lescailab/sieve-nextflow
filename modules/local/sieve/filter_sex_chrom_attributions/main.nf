process SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS {
    tag "$meta.id:${meta.run_id ?: 'sex_chrom_filter'}"
    label 'process_low'

    conda "python=3.11"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(real_variant_rankings, stageAs: 'real/sieve_variant_rankings.csv'), path(null_variant_rankings, stageAs: 'null/sieve_variant_rankings.csv')

    output:
    tuple val(meta), path('real_autosomal_variant_rankings.csv'), path('null_autosomal_variant_rankings.csv'), path('sex_chromosome_filter_summary.yaml'), emit: filtered_rankings
    path 'versions.yml', emit: versions

    script:
    """
    python - <<'PY'
import csv
from pathlib import Path


def normalize_chromosome(variant_id: str) -> str:
    token = (variant_id or '').strip()
    if not token:
        return ''
    chrom = token.split(':', 1)[0].strip()
    if chrom.lower().startswith('chr'):
        chrom = chrom[3:]
    return chrom.upper()


def is_sex_chromosome(variant_id: str) -> bool:
    chrom = normalize_chromosome(variant_id)
    return chrom in {'X', 'Y'}


def filter_rankings(in_path: str, out_path: str) -> tuple[int, int]:
    kept = 0
    removed = 0
    with open(in_path, newline='', encoding='utf-8') as handle_in:
        reader = csv.DictReader(handle_in)
        fieldnames = reader.fieldnames or []
        first_column = fieldnames[0] if fieldnames else None

        with open(out_path, 'w', newline='', encoding='utf-8') as handle_out:
            writer = csv.DictWriter(handle_out, fieldnames=fieldnames)
            if fieldnames:
                writer.writeheader()

            for row in reader:
                variant_id = row.get(first_column, '') if first_column else ''
                if is_sex_chromosome(variant_id):
                    removed += 1
                    continue
                writer.writerow(row)
                kept += 1
    return kept, removed


real_kept, real_removed = filter_rankings('${real_variant_rankings}', 'real_autosomal_variant_rankings.csv')
null_kept, null_removed = filter_rankings('${null_variant_rankings}', 'null_autosomal_variant_rankings.csv')

Path('sex_chromosome_filter_summary.yaml').write_text(
    "\\n".join(
        [
            "filter: remove_sex_chromosomes",
            "chromosomes_removed:",
            "  - X",
            "  - Y",
            "real_rankings:",
            f"  kept: {real_kept}",
            f"  removed: {real_removed}",
            "null_rankings:",
            f"  kept: {null_kept}",
            f"  removed: {null_removed}",
            "",
        ]
    ),
    encoding='utf-8',
)
PY

    python - <<'PY' > .python_version.tmp
import sys
print(f'python: "{sys.version.split()[0]}"')
PY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        \$(cat .python_version.tmp)
END_VERSIONS
    """

    stub:
    """
    cp ${real_variant_rankings} real_autosomal_variant_rankings.csv
    cp ${null_variant_rankings} null_autosomal_variant_rankings.csv

    cat <<'EOF_SUMMARY' > sex_chromosome_filter_summary.yaml
filter: remove_sex_chromosomes
chromosomes_removed:
  - X
  - Y
real_rankings:
  kept: 2
  removed: 0
null_rankings:
  kept: 2
  removed: 0
EOF_SUMMARY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
