process SIEVE_PLOT_ABLATION_COMPARISON {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(jaccard_tsv), path(level_specific_tsv), path(summary_yaml)

    output:
    tuple val(meta), path('ablation_comparison_plot.png'), emit: plot
    path "versions.yml", emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    sieve-plot-ablation-comparison \\
        --jaccard-tsv        ${jaccard_tsv} \\
        --level-specific-tsv ${level_specific_tsv} \\
        --summary-yaml       ${summary_yaml} \\
        --output             ablation_comparison_plot.png \\
        ${args}

    sieve_version=\$(sieve-plot-ablation-comparison --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    touch ablation_comparison_plot.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
