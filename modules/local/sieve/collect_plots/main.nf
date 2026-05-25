process SIEVE_COLLECT_PLOTS {
    tag "$meta.id:${meta.run_id ?: 'collect_plots'}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${(workflow.containerEngine in ['singularity', 'apptainer']) && !task.ext.singularity_pull_docker_container ? 'oras://ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2' : 'ghcr.io/lescailab/sieve-container:97c6b69bbe1c73b2'}"

    input:
    val meta
    val plot_sources

    output:
    tuple val(meta), path('plots'), path('plots_manifest.tsv'), emit: plot_bundle
    path "versions.yml", emit: versions, topic: 'versions'
    when:
    task.ext.when == null || task.ext.when

    script:
    def plotSources = plot_sources instanceof List ? plot_sources : [plot_sources]
    def sourceList = plotSources.collect { source -> source.toString() }.join('\n')
    """
    mkdir -p plots

    cat <<'EOF_PLOT_SOURCES' > .plot_sources.list
${sourceList}
EOF_PLOT_SOURCES

    python - <<'PY'
import csv
import shutil
from pathlib import Path

source_items = [Path(line.strip()) for line in Path('.plot_sources.list').read_text(encoding='utf-8').splitlines() if line.strip()]
plot_exts = {'.png', '.jpg', '.jpeg', '.svg', '.pdf', '.eps', '.tif', '.tiff'}

manifest_rows = []
counter = 0
plots_dir = Path('plots')

def emit_plot(src: Path, origin: Path):
    global counter
    counter += 1
    destination = plots_dir / f"{counter:04d}__{src.name}"
    shutil.copy2(src, destination)
    manifest_rows.append((str(origin), str(src), str(destination)))

for source in source_items:
    if source.is_dir():
        for candidate in sorted(source.rglob('*')):
            if candidate.is_file() and candidate.suffix.lower() in plot_exts:
                emit_plot(candidate, source)
    elif source.is_file() and source.suffix.lower() in plot_exts:
        emit_plot(source, source.parent)

if counter == 0:
    placeholder = plots_dir / '0000__no_plots_found.txt'
    placeholder.write_text('No plot files were found in the provided sources.\\n', encoding='utf-8')

with open('plots_manifest.tsv', 'w', newline='', encoding='utf-8') as handle:
    writer = csv.writer(handle, delimiter='\\t')
    writer.writerow(['source_root', 'source_file', 'published_plot'])
    writer.writerows(manifest_rows)
PY

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
    mkdir -p plots
    touch plots/0001__example_plot.png

    cat <<'EOF_MANIFEST' > plots_manifest.tsv
source_root	source_file	published_plot
stub	stub/0001__example_plot.png	plots/0001__example_plot.png
EOF_MANIFEST

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "stub"
END_VERSIONS
    """
}
