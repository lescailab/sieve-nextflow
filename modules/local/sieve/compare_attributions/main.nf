process SIEVE_COMPARE_ATTRIBUTIONS {
    tag "$meta.id:${meta.run_id ?: 'compare_attributions'}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:803e8d8c7e63be61' : 'ghcr.io/lescailab/sieve-container:803e8d8c7e63be61'}"

    input:
    tuple val(meta), path(real_variant_rankings, stageAs: 'real/sieve_variant_rankings.csv'), path(null_variant_rankings, stageAs: 'null/sieve_variant_rankings.csv')

    output:
    tuple val(meta), path('comparison_summary.yaml'), path('comparison_output'), emit: comparison
    tuple val(meta), path('comparison_output/variant_rankings_with_significance.csv'), optional: true, emit: significance_rankings
    path "versions.yml", emit: versions, topic: 'versions'
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p comparison_output

    sieve-compare-attributions \\
        --real ${real_variant_rankings} \\
        --null ${null_variant_rankings} \\
        --output-dir comparison_output \\
        ${args}

    summary_candidate=\$(find comparison_output -maxdepth 3 -type f \\( -name 'comparison_summary.yaml' -o -name '*summary*.yaml' \\) | head -n 1 || true)

    if [[ -n "\${summary_candidate}" ]]; then
        cp "\${summary_candidate}" comparison_summary.yaml
    else
        cat <<'EOF_SUMMARY' > comparison_summary.yaml
metric_priority:
  - auc
  - accuracy
  - loss
significant_variants: 0
EOF_SUMMARY
    fi

    cp comparison_summary.yaml comparison_output/comparison_summary.yaml

    sieve_version=\$(sieve-compare-attributions --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p comparison_output

    cat <<'EOF_SUMMARY' > comparison_summary.yaml
metric_priority:
  - auc
  - accuracy
  - loss
significant_variants: 2
EOF_SUMMARY

    cat <<'EOF_CSV' > comparison_output/variant_rankings_with_significance.csv
variant_id,z_attribution,empirical_p_variant,fdr_variant
1:100_A/T,3.21,0.002,0.010
1:101_G/C,2.87,0.011,0.035
EOF_CSV

    cat <<'EOF_SIG' > comparison_output/significant_variants.csv
variant_id,delta_score,pvalue
1:100_A/T,0.34,0.002
1:101_G/C,0.27,0.011
EOF_SIG

    cp comparison_summary.yaml comparison_output/comparison_summary.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
