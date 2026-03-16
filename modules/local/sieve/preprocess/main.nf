process SIEVE_PREPROCESS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:04d9d6e221e64045' : 'ghcr.io/lescailab/sieve-container:04d9d6e221e64045'}"

    input:
    tuple val(meta), path(vcf), path(phenotypes), path(sex_map)
    val genome_build

    output:
    tuple val(meta), path('preprocessed.pt'), emit: preprocessed
    tuple val("${task.process}"), val('sieve'), val('1.0.0'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    sieve-preprocess \
        --vcf ${vcf} \
        --phenotypes ${phenotypes} \
        --output preprocessed.pt \
        --sex-map ${sex_map} \
        --genome-build ${genome_build} \
        ${args}

    [[ -f preprocessed.pt ]] || { echo "ERROR: preprocess did not create preprocessed.pt" >&2; exit 1; }

    sieve_version=\$(sieve-preprocess --version 2>/dev/null | head -n 1 || echo "unknown")

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
