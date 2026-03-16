process SIEVE_CREATE_NULL_BASELINE {
    tag "$meta.id:${meta.run_id ?: 'null_baseline'}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    tuple val(meta), path(preprocessed), val(seed)

    output:
    tuple val(meta), path('preprocessed_NULL.pt'), emit: null_preprocessed
    tuple val("${task.process}"), val('sieve'), val('1.0.0'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    sieve-create-null-baseline \
        --input ${preprocessed} \
        --output preprocessed_NULL.pt \
        --seed ${seed} \
        ${args}

    [[ -f preprocessed_NULL.pt ]] || { echo "ERROR: create_null_baseline did not produce preprocessed_NULL.pt" >&2; exit 1; }

    sieve_version=\$(sieve-create-null-baseline --version 2>/dev/null | head -n 1 || echo "unknown")

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    touch preprocessed_NULL.pt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
