//
// Subworkflow: Validate discoveries against reference databases and collect plots
//

include { SIEVE_VALIDATE_DISCOVERIES } from '../../../modules/local/sieve/validate_discoveries/main'
include { SIEVE_COLLECT_PLOTS        } from '../../../modules/local/sieve/collect_plots/main'
include { resolveExecuteSteps } from '../../../lib/sieve_helpers'

workflow VALIDATION {

    take:
    ch_selection_meta      // channel: val([id: cohort_id])
    ch_real_rankings       // channel: [ val(meta), path(variant), path(gene), path(interactions) ]
    ch_ref_clinvar         // channel: path(clinvar)
    ch_ref_gwas            // channel: path(gwas)
    ch_ref_go_mapping      // channel: path(go_mapping)
    ch_plot_sources        // channel: path(plot_files) — accumulated from all subworkflows

    main:

    ch_versions = channel.empty()
    ch_published_explainability_analysis = channel.empty()
    ch_published_plots = channel.empty()

    def selectedSteps = resolveExecuteSteps(params.execute_step)
    def targetValidation = selectedSteps.contains('validation')
    def targetPlots = selectedSteps.contains('plots')

    //
    // Validate discoveries against reference databases
    //
    if (targetValidation) {
        def missingOptionalRefToken = '__SIEVE_OPTIONAL_REF_MISSING__'

        ch_discovery_validation_input = ch_real_rankings
            .combine(ch_ref_clinvar)
            .combine(ch_ref_gwas)
            .combine(ch_ref_go_mapping)
            .map { meta, variant_rankings, gene_rankings, _interactions, clinvar, gwas, go ->
                def clinvarInput = clinvar == missingOptionalRefToken ? [] : clinvar
                def gwasInput = gwas == missingOptionalRefToken ? [] : gwas
                def goInput = go == missingOptionalRefToken ? [] : go

                tuple(
                    [id: meta.id, run_id: 'discoveries_validation', stage: 'validation'],
                    variant_rankings,
                    gene_rankings,
                    clinvarInput,
                    gwasInput,
                    goInput
                )
            }

        SIEVE_VALIDATE_DISCOVERIES(ch_discovery_validation_input)
        ch_versions = ch_versions.mix(SIEVE_VALIDATE_DISCOVERIES.out.versions)

        ch_plot_sources = ch_plot_sources.mix(SIEVE_VALIDATE_DISCOVERIES.out.validation.map { _meta, _validation_report, validation_dir -> validation_dir })

        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
            SIEVE_VALIDATE_DISCOVERIES.out.validation.map { _meta, validation_report, validation_dir ->
                [validation_report, validation_dir]
            }
        )
    }

    //
    // Collect plots from all subworkflows
    //
    if (targetPlots) {
        ch_plot_sources_list = ch_plot_sources.collect()

        SIEVE_COLLECT_PLOTS(
            ch_selection_meta,
            ch_plot_sources_list
        )
        ch_versions = ch_versions.mix(SIEVE_COLLECT_PLOTS.out.versions)

        ch_published_plots = SIEVE_COLLECT_PLOTS.out.plot_bundle
            .flatMap { _meta, plots_dir, plots_manifest ->
                def published = []
                if (plots_dir instanceof Collection) {
                    published.addAll(plots_dir)
                } else if (plots_dir != null) {
                    published << plots_dir
                }
                if (plots_manifest != null) {
                    published << plots_manifest
                }
                published
            }
    }

    emit:
    published_explainability_analysis = ch_published_explainability_analysis  // channel: publish files
    published_plots                   = ch_published_plots                    // channel: path(plot_files)
    versions                          = ch_versions                           // channel: path(versions.yml)
}
