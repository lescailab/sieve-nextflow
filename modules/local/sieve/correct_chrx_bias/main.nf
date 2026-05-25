process SIEVE_CORRECT_CHRX_BIAS {
    tag "$meta.id:${meta.run_id ?: 'correct_chrx'}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(rankings_with_significance)

    output:
    tuple val(meta), path('corrected'), emit: corrected
    path "versions.yml", emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p corrected

    sieve-correct-chrx-bias \\
        --rankings ${rankings_with_significance} \\
        --output-dir corrected \\
        ${args}

    sieve_version=\$(sieve-correct-chrx-bias --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p corrected

    cp ${rankings_with_significance} corrected/corrected_variant_rankings.csv
    cat <<'EOF_GENE' > corrected/corrected_gene_rankings.csv
gene_name,gene_z_score,num_variants,mean_z_score,top_variant_pos,gene_rank
GENE1,3.21,1,3.21,100,1
GENE2,2.87,1,2.87,101,2
EOF_GENE
    touch corrected/corrected_manhattan_plot.png
    cat <<'EOF_REPORT' > corrected/correction_report.yaml
total_variants: 2
autosomal_variants: 2
sex_chrom_variants: 0
EOF_REPORT

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
