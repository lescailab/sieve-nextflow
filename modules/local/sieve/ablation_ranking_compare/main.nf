process SIEVE_ABLATION_RANKING_COMPARE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:803e8d8c7e63be61' : 'ghcr.io/lescailab/sieve-container:803e8d8c7e63be61'}"

    input:
    val meta
    path ranking_files

    output:
    tuple val(meta), path('ablation_jaccard_matrix.tsv'), path('level_specific_variants.tsv'), emit: ranking_comparison
    path "versions.yml", emit: versions, topic: 'versions'
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    sieve-compare-ablation-rankings \\
        --ranking-dir . \\
        --score-column z_attribution \\
        --top-k 50,100,200,500 \\
        --out-jaccard ablation_jaccard_matrix.tsv \\
        --out-level-specific level_specific_variants.tsv \\
        ${args}

    sieve_version=\$(sieve-compare-ablation-rankings --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    cat <<'EOF_TSV' > ablation_jaccard_matrix.tsv
top_k\tlevel_a\tlevel_b\tjaccard\toverlap\tsize_a\tsize_b\tunion
50\tL0\tL1\t0.3500\t21\t50\t50\t60
50\tL0\tL2\t0.2800\t18\t50\t50\t64
50\tL0\tL3\t0.2200\t15\t50\t50\t68
50\tL1\tL2\t0.4500\t28\t50\t50\t62
50\tL1\tL3\t0.3800\t24\t50\t50\t63
50\tL2\tL3\t0.5500\t34\t50\t50\t62
EOF_TSV

    cat <<'EOF_LSV' > level_specific_variants.tsv
variant_id\tgene\tchrom\tpos\tspecific_to_level\tz_attribution
1:100_A/T\tGENE1\t1\t100\tL0\t0.91
1:101_G/C\tGENE2\t1\t101\tL1\t0.85
EOF_LSV

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
