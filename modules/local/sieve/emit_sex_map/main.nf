process SIEVE_EMIT_SEX_MAP {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), path(sex_map)

    output:
    tuple val(meta), path('sample_sex.tsv'), emit: sex_map
    tuple val("${task.process}"), val('python'), val('3.11'), emit: versions, topic: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cp ${sex_map} sample_sex.tsv.tmp
    mv sample_sex.tsv.tmp sample_sex.tsv

    python - <<'PY' > .python_version.tmp
import sys
print(f'python: "{sys.version.split()[0]}"')
PY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        \$(cat .python_version.tmp)
END_VERSIONS
    """

    stub:
    """
    cp ${sex_map} sample_sex.tsv.tmp
    mv sample_sex.tsv.tmp sample_sex.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
