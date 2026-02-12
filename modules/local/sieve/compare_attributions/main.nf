process SIEVE_COMPARE_ATTRIBUTIONS {
    tag "$meta.id:${meta.run_id ?: 'compare_attributions'}"
    label 'process_medium'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(real_variant_rankings, stageAs: 'real/sieve_variant_rankings.csv'), path(null_variant_rankings, stageAs: 'null/sieve_variant_rankings.csv')

    output:
    tuple val(meta), path('comparison_summary.yaml'), path('comparison_output'), emit: comparison
    path 'versions.yml', emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p comparison_output

    sieve_cmd.sh compare_attributions \
        --real ${real_variant_rankings} \
        --null ${null_variant_rankings} \
        --output-dir comparison_output \
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

    sieve_version=\$(sieve_cmd.sh --version 2>/dev/null | head -n 1 || true)
    [[ -z "\${sieve_version}" ]] && sieve_version="unknown"

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

    cat <<'EOF_CSV' > comparison_output/significant_variants.csv
variant_id,delta_score,pvalue
1:100_A/T,0.34,0.002
1:101_G/C,0.27,0.011
EOF_CSV

    cp comparison_summary.yaml comparison_output/comparison_summary.yaml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
