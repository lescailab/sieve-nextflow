/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PREPROCESS        } from '../subworkflows/local/preprocess/main'
include { TRAIN_AND_EXPLAIN } from '../subworkflows/local/train_and_explain/main'
include { ABLATION          } from '../subworkflows/local/ablation/main'
include { EPISTASIS         } from '../subworkflows/local/epistasis/main'
include { VALIDATION        } from '../subworkflows/local/validation/main'
include { resolveExecuteSteps; softwareVersionsToYAML } from '../lib/sieve_helpers'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SIEVE {

    main:

    ch_versions = channel.empty()
    ch_plot_sources = channel.empty()

    def cohortMeta = [id: params.cohort_id ?: 'cohort']
    def ch_selection_meta = channel.value([id: cohortMeta.id])

    def selectedSteps = resolveExecuteSteps(params.execute_step)
    log.info("Executing SIEVE steps: ${selectedSteps.join(', ')}")

    def targetExplain = selectedSteps.contains('explain')
    def targetAblation = selectedSteps.contains('ablation')
    def targetNull = selectedSteps.contains('null')
    def targetEpistasis = selectedSteps.contains('epistasis')
    def targetValidation = selectedSteps.contains('validation')
    def targetPlots = selectedSteps.contains('plots')

    def needExplain = targetExplain || targetEpistasis || targetValidation || targetNull
    def needBestCheckpoint = selectedSteps.contains('cv') || needExplain

    //
    // SUBWORKFLOW: Preprocess — sex map, preprocessed data, grid search, best params, reference databases
    //
    PREPROCESS(ch_selection_meta)
    ch_versions = ch_versions.mix(PREPROCESS.out.versions)
    ch_plot_sources = ch_plot_sources.mix(PREPROCESS.out.plot_sources)

    //
    // SUBWORKFLOW: Train and explain — CV training, best checkpoint, explainability, null baseline comparison
    //
    ch_published_best_model = channel.empty()
    ch_published_explainability_best = channel.empty()
    ch_published_null_model = channel.empty()
    ch_published_null_comparison = channel.empty()
    ch_published_null_comparison_sex_fixed = channel.empty()
    ch_real_rankings = channel.empty()
    ch_null_attributions_npz = channel.value([])
    ch_null_variant_rankings = channel.value([])
    ch_best_checkpoint_keyed = channel.empty()

    if (needBestCheckpoint || needExplain || targetNull) {
        TRAIN_AND_EXPLAIN(
            ch_selection_meta,
            PREPROCESS.out.preprocessed_keyed,
            PREPROCESS.out.sex_map_keyed,
            PREPROCESS.out.best_params_path_keyed,
            PREPROCESS.out.best_params_map_keyed
        )
        ch_versions = ch_versions.mix(TRAIN_AND_EXPLAIN.out.versions)
        ch_plot_sources = ch_plot_sources.mix(TRAIN_AND_EXPLAIN.out.plot_sources)
        ch_published_best_model = TRAIN_AND_EXPLAIN.out.published_best_model
        ch_published_explainability_best = TRAIN_AND_EXPLAIN.out.published_explainability_best
        ch_published_null_model = TRAIN_AND_EXPLAIN.out.published_null_model
        ch_published_null_comparison = TRAIN_AND_EXPLAIN.out.published_null_comparison
        ch_published_null_comparison_sex_fixed = TRAIN_AND_EXPLAIN.out.published_null_comparison_sex_fixed
        ch_real_rankings = TRAIN_AND_EXPLAIN.out.real_rankings
        ch_null_attributions_npz = TRAIN_AND_EXPLAIN.out.null_attributions_npz
        ch_null_variant_rankings = TRAIN_AND_EXPLAIN.out.null_variant_rankings
        ch_best_checkpoint_keyed = TRAIN_AND_EXPLAIN.out.best_checkpoint_keyed
    }

    //
    // SUBWORKFLOW: Ablation — train per-level models, explain, and compare
    //
    ch_published_ablation_discovery = channel.empty()

    if (targetAblation) {
        ABLATION(
            ch_selection_meta,
            PREPROCESS.out.preprocessed_keyed,
            PREPROCESS.out.sex_map_keyed,
            PREPROCESS.out.best_params_map_keyed
        )
        ch_versions = ch_versions.mix(ABLATION.out.versions)
        ch_plot_sources = ch_plot_sources.mix(ABLATION.out.plot_sources)
        ch_published_ablation_discovery = ABLATION.out.published_ablation_discovery
    }

    //
    // SUBWORKFLOW: Epistasis — audit co-occurrence, validate, power analysis, gene interactions
    //
    ch_published_explainability_analysis = channel.empty()

    if (targetEpistasis) {
        EPISTASIS(
            PREPROCESS.out.preprocessed,
            PREPROCESS.out.preprocessed_keyed,
            ch_real_rankings,
            ch_best_checkpoint_keyed,
            ch_null_attributions_npz,
            ch_null_variant_rankings
        )
        ch_versions = ch_versions.mix(EPISTASIS.out.versions)
        ch_plot_sources = ch_plot_sources.mix(EPISTASIS.out.plot_sources)
        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(EPISTASIS.out.published_explainability_analysis)
    }

    //
    // SUBWORKFLOW: Validation — validate discoveries and collect plots
    //
    ch_published_plots = channel.empty()

    if (targetValidation || targetPlots) {
        VALIDATION(
            ch_selection_meta,
            ch_real_rankings,
            PREPROCESS.out.ref_clinvar,
            PREPROCESS.out.ref_gwas,
            PREPROCESS.out.ref_go_mapping,
            ch_plot_sources
        )
        ch_versions = ch_versions.mix(VALIDATION.out.versions)
        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(VALIDATION.out.published_explainability_analysis)
        ch_published_plots = VALIDATION.out.published_plots
    }

    softwareVersionsToYAML(ch_versions)
        .collectFile(
            name: 'nf_core_sieve_software_versions.yml',
            sort: true,
            newLine: true
        )
        .set { ch_collated_versions }

    ch_published_sex_map = PREPROCESS.out.sex_map.map { _meta, sex_map_file ->
        sex_map_file
    }

    ch_published_preprocessed = PREPROCESS.out.preprocessed.map { _meta, preprocessed_file ->
        preprocessed_file
    }

    emit:
    sex_map                    = ch_published_sex_map
    preprocessed_dataset       = ch_published_preprocessed
    best_model                 = ch_published_best_model
    explainability_best_model  = ch_published_explainability_best
    explainability_analysis    = ch_published_explainability_analysis
    ablation_discovery         = ch_published_ablation_discovery
    null_model                 = ch_published_null_model
    null_comparison            = ch_published_null_comparison
    null_comparison_sex_fixed  = ch_published_null_comparison_sex_fixed
    plots                      = ch_published_plots
    pipeline_versions          = ch_collated_versions
    versions                   = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
