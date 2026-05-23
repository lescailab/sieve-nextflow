process SIEVE_BOOTSTRAP_NULL_CALIBRATION {
    tag "$meta.id:${meta.level ?: 'bootstrap'}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(real_rankings), path(null_attributions_npz)

    output:
    tuple val(meta), path('calibrated_rankings.csv'), emit: calibrated
    path "versions.yml", emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args ?: ''
    def nBoot   = params.null_bootstrap ?: 1000
    """
    sieve-bootstrap-null-calibration \\
        --real-rankings     ${real_rankings} \\
        --null-attributions ${null_attributions_npz} \\
        --output            calibrated_rankings.csv \\
        --n-bootstrap       ${nBoot} \\
        ${args}

    sieve_version=\$(sieve-bootstrap-null-calibration --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    cat <<'EOF_CAL' > calibrated_rankings.csv
variant_id,z_attribution,empirical_p_variant,fdr_variant,delta_rank
1:100_A/T,3.21,0.002,0.010,15
1:101_G/C,2.87,0.011,0.035,22
EOF_CAL

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
