process SIEVE_EMIT_BEST_PARAMS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), val(params_map)

    output:
    tuple val(meta), path('best_params.yaml'), emit: best_params
    tuple val("${task.process}"), val('python'), val('3.11'), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def paramsJson = groovy.json.JsonOutput.toJson(params_map ?: [:])
    """
    python - <<PY
import json
import yaml

payload = json.loads('${paramsJson}')
serialisable = {k: v for k, v in payload.items() if v is not None}
with open('best_params.yaml', 'w') as fh:
    yaml.safe_dump(serialisable, fh, sort_keys=False, default_flow_style=False)
PY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version 2>&1 | awk '{print \$2}')"
END_VERSIONS
    """

    stub:
    def paramsJsonStub = groovy.json.JsonOutput.toJson(params_map ?: [:])
    """
    python - <<PY
import json
import yaml

payload = json.loads('${paramsJsonStub}')
serialisable = {k: v for k, v in payload.items() if v is not None}
with open('best_params.yaml', 'w') as fh:
    yaml.safe_dump(serialisable, fh, sort_keys=False, default_flow_style=False)
PY

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
