process SIEVE_EPISTASIS_POWER_ANALYSIS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    tuple val(meta), path(cooccurrence_pairs), path(cooccurrence_summary)
    path null_attributions_npz
    path epistasis_results

    output:
    tuple val(meta), path('power_output'), path('power_analysis_summary.yaml'), emit: power_analysis
    path 'versions.yml',                                                        emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def null_attr_arg = null_attributions_npz ? "--null-attributions-npz ${null_attributions_npz}" : ''
    def epistasis_arg = epistasis_results ? "--epistasis-results ${epistasis_results}" : ''
    """
    mkdir -p power_output

    sieve-epistasis-power-analysis \
        --cooccurrence ${cooccurrence_pairs} \
        --cooccurrence-summary ${cooccurrence_summary} \
        --output-dir power_output \
        ${null_attr_arg} \
        ${epistasis_arg} \
        ${args}

    # Copy summary to working directory for explicit emission
    cp power_output/power_analysis_summary.yaml power_analysis_summary.yaml

    sieve_version=\$(sieve-epistasis-power-analysis --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p power_output

    cat <<'EOF_POWER' > power_output/power_analysis_per_pair.csv
variant_a,variant_b,mde,n_effective
1:100_A/T,1:200_G/C,0.08,42.5
EOF_POWER

    cat <<'EOF_SUMMARY' > power_output/power_analysis_by_maf_bin.csv
maf_bin_a,maf_bin_b,median_mde,n_testable
0.01-0.05,0.01-0.05,0.12,50
EOF_SUMMARY

    cat <<'EOF_YAML' > power_analysis_summary.yaml
sigma_synergy: 0.05
median_mde: 0.12
n_testable_pairs: 50
EOF_YAML

    touch power_output/power_analysis_plot.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
