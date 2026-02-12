process SIEVE_PREPROCESS {
    tag "$meta.id"
    label 'process_medium'

    conda "lescailab::sieve=0.1.0"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://community.wave.seqera.io/library/sieve:0.1.0--7766b34e148e6eef' : 'community.wave.seqera.io/library/sieve:0.1.0--dee13fc1b5eb4382'}"

    input:
    tuple val(meta), path(vcf), path(phenotypes), path(sex_map)
    val genome_build

    output:
    tuple val(meta), path('preprocessed.pt'), emit: preprocessed
    path 'versions.yml', emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    sieve_cmd.sh preprocess \
        --vcf ${vcf} \
        --phenotypes ${phenotypes} \
        --output preprocessed.pt \
        --sex-map ${sex_map} \
        --genome-build ${genome_build} \
        ${args}

    [[ -f preprocessed.pt ]] || { echo "ERROR: preprocess did not create preprocessed.pt" >&2; exit 1; }

    sieve_version=\$(sieve_cmd.sh --version 2>/dev/null | head -n 1 || true)
    [[ -z "\${sieve_version}" ]] && sieve_version="unknown"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "\${sieve_version}"
END_VERSIONS
    """

    stub:
    """
    touch preprocessed.pt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sieve: "stub"
END_VERSIONS
    """
}
