process SIEVE_GENERATE_GENE_LIST {
    tag "$meta.id:${meta.level ?: 'gene_list'}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(corrected_variant_rankings), path(calibrated_rankings)

    output:
    tuple val(meta), path('gene_list_by_delta_rank.tsv'),       emit: gene_list_delta
    tuple val(meta), path('gene_list_by_z_attribution.tsv'),    emit: gene_list_zattr
    tuple val(meta), path('variant_significance_rankings.csv'), emit: variant_rankings
    path "versions.yml", emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    sieve-generate-gene-list \\
        --variant-rankings ${calibrated_rankings} \\
        --score-column delta_rank \\
        --output gene_list_by_delta_rank.tsv \\
        ${args}

    sieve-generate-gene-list \\
        --variant-rankings ${corrected_variant_rankings} \\
        --score-column z_attribution \\
        --output gene_list_by_z_attribution.tsv \\
        ${args}

    cp ${corrected_variant_rankings} variant_significance_rankings.csv

    sieve_version=\$(sieve-generate-gene-list --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    cat <<'EOF_DELTA' > gene_list_by_delta_rank.tsv
gene\tdelta_rank\tz_attribution
GENE1\t1\t3.21
GENE2\t2\t2.87
EOF_DELTA

    cat <<'EOF_ZATTR' > gene_list_by_z_attribution.tsv
gene\tz_attribution\tdelta_rank
GENE1\t3.21\t1
GENE2\t2.87\t2
EOF_ZATTR

    cp ${corrected_variant_rankings} variant_significance_rankings.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
