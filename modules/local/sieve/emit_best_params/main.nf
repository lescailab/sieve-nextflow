process SIEVE_EMIT_BEST_PARAMS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    tuple val(meta), val(params_map)

    output:
    tuple val(meta), path('best_params.yaml'), emit: best_params
    path "versions.yml", emit: versions, topic: 'versions'

    when:
    task.ext.when == null || task.ext.when

    script:
    // Render the in-memory params map to a side-file as JSON, then let Python load it.
    // This avoids interpolating untrusted values into the embedded Python script.
    def paramsJson = groovy.json.JsonOutput.toJson(params_map ?: [:])
    """
    cat > params.json <<'PARAMS_JSON_EOF'
${paramsJson}
PARAMS_JSON_EOF

    python <<'PY'
import json
import yaml

with open('params.json') as fh:
    payload = json.load(fh)
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
    cat > params.json <<'PARAMS_JSON_EOF'
${paramsJsonStub}
PARAMS_JSON_EOF

    python <<'PY'
import json
import yaml

with open('params.json') as fh:
    payload = json.load(fh)
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
