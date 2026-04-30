process SIEVE_AUDIT_COOCCURRENCE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:803e8d8c7e63be61' : 'ghcr.io/lescailab/sieve-container:803e8d8c7e63be61'}"

    input:
    tuple val(meta), path(preprocessed)

    output:
    tuple val(meta), path('cooccurrence_output'),          emit: cooccurrence_dir
    tuple val(meta), path('cooccurrence_per_pair.csv'),    emit: cooccurrence_pairs
    tuple val(meta), path('cooccurrence_by_maf_bin.csv'),  emit: cooccurrence_summary
    tuple val("${task.process}"), val('sieve'), val('1.0.0'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p cooccurrence_output

    sieve-audit-cooccurrence \
        --preprocessed-data ${preprocessed} \
        --output-dir cooccurrence_output \
        ${args}

    # Copy key outputs to working directory for explicit channel emission
    cp cooccurrence_output/cooccurrence_per_pair.csv cooccurrence_per_pair.csv
    cp cooccurrence_output/cooccurrence_by_maf_bin.csv cooccurrence_by_maf_bin.csv

    sieve_version=\$(sieve-audit-cooccurrence --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p cooccurrence_output

    cat <<'EOF_PAIRS' > cooccurrence_per_pair.csv
variant_a,variant_b,n11,n10,n01,n00,obs_exp_ratio,maf_bin_a,maf_bin_b
1:100_A/T,1:200_G/C,5,10,8,77,1.2,0.01-0.05,0.01-0.05
EOF_PAIRS

    cat <<'EOF_SUMMARY' > cooccurrence_by_maf_bin.csv
maf_bin_a,maf_bin_b,n_pairs,median_n11,frac_testable
0.01-0.05,0.01-0.05,100,3,0.45
EOF_SUMMARY

    cat <<'EOF_YAML' > cooccurrence_output/cooccurrence_summary.yaml
n_samples: 100
n_variants: 500
conclusion: feasible
EOF_YAML

    cp cooccurrence_per_pair.csv cooccurrence_output/cooccurrence_per_pair.csv
    cp cooccurrence_by_maf_bin.csv cooccurrence_output/cooccurrence_by_maf_bin.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
