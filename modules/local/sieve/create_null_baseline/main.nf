process SIEVE_CREATE_NULL_BASELINE {
    tag "$meta.id:${meta.run_id ?: 'null_baseline'}"
    label 'process_medium'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(preprocessed), val(seed)

    output:
    tuple val(meta), path('preprocessed_NULL.pt'), emit: null_preprocessed
    path 'versions.yml', emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    sieve_cmd.sh create_null_baseline \
        --input ${preprocessed} \
        --output preprocessed_NULL.pt \
        --seed ${seed} \
        ${args}

    [[ -f preprocessed_NULL.pt ]] || { echo "ERROR: create_null_baseline did not produce preprocessed_NULL.pt" >&2; exit 1; }

    sieve_version=\$(sieve_cmd.sh --version 2>/dev/null | head -n 1 || true)
    [[ -z "\${sieve_version}" ]] && sieve_version="unknown"

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
