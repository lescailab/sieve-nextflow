process SIEVE_VALIDATE_EPISTASIS {
    tag "$meta.id:${meta.run_id ?: 'validate_epistasis'}"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(interactions_csv), path(checkpoint), path(config), path(preprocessed)

    output:
    tuple val(meta), path('epistasis_validation.csv'), path('epistasis_output'), emit: epistasis
    tuple val("${task.process}"), val('sieve'), val('1.0.0'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p epistasis_output

    sieve-validate-epistasis \
        --interactions ${interactions_csv} \
        --checkpoint ${checkpoint} \
        --config ${config} \
        --preprocessed-data ${preprocessed} \
        --output-dir epistasis_output \
        ${args}

    result_candidate=\$(find epistasis_output -maxdepth 3 -type f \\( -name 'epistasis_validation.csv' -o -name '*epistasis*validation*.csv' \\) | head -n 1 || true)

    if [[ -n "\${result_candidate}" ]]; then
        cp "\${result_candidate}" epistasis_validation.csv
    else
        cat <<'EOF_EPI' > epistasis_validation.csv
variant_a,variant_b,validated
EOF_EPI
    fi

    cp epistasis_validation.csv epistasis_output/epistasis_validation.csv

    sieve_version=\$(sieve-validate-epistasis --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    mkdir -p epistasis_output

    cat <<'EOF_EPI' > epistasis_validation.csv
variant_a,variant_b,validated
1:100_A/T,1:101_G/C,true
EOF_EPI

    cp epistasis_validation.csv epistasis_output/epistasis_validation.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
