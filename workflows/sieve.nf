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
    ch_published_cv_folds = channel.empty()
    ch_published_explainability_best = channel.empty()
    ch_published_null_model = channel.empty()
    ch_published_null_attributions = channel.empty()
    ch_published_null_comparison = channel.empty()
    ch_published_null_comparison_corrected = channel.empty()
    ch_published_bootstrap_calibration = channel.empty()
    ch_published_gene_list_delta = channel.empty()
    ch_published_gene_list_zattr = channel.empty()
    ch_published_variant_significance = channel.empty()
    ch_real_rankings = channel.empty()
    ch_null_attributions_npz = channel.value([])
    ch_null_variant_rankings = channel.value([])
    ch_best_checkpoint_keyed = channel.empty()
    ch_null_preprocessed_keyed = channel.empty()

    if (needBestCheckpoint || needExplain || targetNull || targetAblation) {
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
        ch_published_cv_folds = TRAIN_AND_EXPLAIN.out.published_cv_folds
        ch_published_explainability_best = TRAIN_AND_EXPLAIN.out.published_explainability_best
        ch_published_null_model = TRAIN_AND_EXPLAIN.out.published_null_model
        ch_published_null_attributions = TRAIN_AND_EXPLAIN.out.published_null_attributions
        ch_published_null_comparison = TRAIN_AND_EXPLAIN.out.published_null_comparison
        ch_published_null_comparison_corrected = TRAIN_AND_EXPLAIN.out.published_null_comparison_corrected
        ch_published_bootstrap_calibration = TRAIN_AND_EXPLAIN.out.published_bootstrap_calibration
        ch_published_gene_list_delta = TRAIN_AND_EXPLAIN.out.published_gene_list_delta
        ch_published_gene_list_zattr = TRAIN_AND_EXPLAIN.out.published_gene_list_zattr
        ch_published_variant_significance = TRAIN_AND_EXPLAIN.out.published_variant_significance
        ch_real_rankings = TRAIN_AND_EXPLAIN.out.real_rankings
        ch_null_attributions_npz = TRAIN_AND_EXPLAIN.out.null_attributions_npz
        ch_null_variant_rankings = TRAIN_AND_EXPLAIN.out.null_variant_rankings
        ch_best_checkpoint_keyed = TRAIN_AND_EXPLAIN.out.best_checkpoint_keyed
        ch_null_preprocessed_keyed = TRAIN_AND_EXPLAIN.out.null_preprocessed_keyed
    }

    //
    // SUBWORKFLOW: Ablation — train per-level models, explain, per-level null comparison, gene lists, compare
    //
    ch_ablation_training_l0 = channel.empty()
    ch_ablation_training_l1 = channel.empty()
    ch_ablation_training_l2 = channel.empty()
    ch_ablation_training_l3 = channel.empty()
    ch_ablation_attributions_l0 = channel.empty()
    ch_ablation_attributions_l1 = channel.empty()
    ch_ablation_attributions_l2 = channel.empty()
    ch_ablation_attributions_l3 = channel.empty()
    ch_ablation_null_training_l0 = channel.empty()
    ch_ablation_null_training_l1 = channel.empty()
    ch_ablation_null_training_l2 = channel.empty()
    ch_ablation_null_training_l3 = channel.empty()
    ch_ablation_null_attributions_l0 = channel.empty()
    ch_ablation_null_attributions_l1 = channel.empty()
    ch_ablation_null_attributions_l2 = channel.empty()
    ch_ablation_null_attributions_l3 = channel.empty()
    ch_ablation_comparison_l0 = channel.empty()
    ch_ablation_comparison_l1 = channel.empty()
    ch_ablation_comparison_l2 = channel.empty()
    ch_ablation_comparison_l3 = channel.empty()
    ch_ablation_comparison_corrected_l0 = channel.empty()
    ch_ablation_comparison_corrected_l1 = channel.empty()
    ch_ablation_comparison_corrected_l2 = channel.empty()
    ch_ablation_comparison_corrected_l3 = channel.empty()
    ch_ablation_bootstrap_l0 = channel.empty()
    ch_ablation_bootstrap_l1 = channel.empty()
    ch_ablation_bootstrap_l2 = channel.empty()
    ch_ablation_bootstrap_l3 = channel.empty()
    ch_ablation_gene_delta_l0 = channel.empty()
    ch_ablation_gene_delta_l1 = channel.empty()
    ch_ablation_gene_delta_l2 = channel.empty()
    ch_ablation_gene_delta_l3 = channel.empty()
    ch_ablation_gene_zattr_l0 = channel.empty()
    ch_ablation_gene_zattr_l1 = channel.empty()
    ch_ablation_gene_zattr_l2 = channel.empty()
    ch_ablation_gene_zattr_l3 = channel.empty()
    ch_ablation_variant_significance_l0 = channel.empty()
    ch_ablation_variant_significance_l1 = channel.empty()
    ch_ablation_variant_significance_l2 = channel.empty()
    ch_ablation_variant_significance_l3 = channel.empty()
    ch_published_ablation_comparison = channel.empty()

    if (targetAblation) {
        ABLATION(
            ch_selection_meta,
            PREPROCESS.out.preprocessed_keyed,
            PREPROCESS.out.sex_map_keyed,
            PREPROCESS.out.best_params_map_keyed,
            ch_null_preprocessed_keyed
        )
        ch_versions = ch_versions.mix(ABLATION.out.versions)
        ch_plot_sources = ch_plot_sources.mix(ABLATION.out.plot_sources)
        ch_published_ablation_comparison = ABLATION.out.published_ablation_comparison

        // Split per-level channels by meta.level for publishing
        ch_ablation_training_l0 = ABLATION.out.ablation_training_per_level.filter { meta, _d -> meta.level == 'L0' }.map { _meta, d -> d }
        ch_ablation_training_l1 = ABLATION.out.ablation_training_per_level.filter { meta, _d -> meta.level == 'L1' }.map { _meta, d -> d }
        ch_ablation_training_l2 = ABLATION.out.ablation_training_per_level.filter { meta, _d -> meta.level == 'L2' }.map { _meta, d -> d }
        ch_ablation_training_l3 = ABLATION.out.ablation_training_per_level.filter { meta, _d -> meta.level == 'L3' }.map { _meta, d -> d }

        ch_ablation_attributions_l0 = ABLATION.out.ablation_attributions_per_level.filter { meta, _d -> meta.level == 'L0' }.map { _meta, d -> d }
        ch_ablation_attributions_l1 = ABLATION.out.ablation_attributions_per_level.filter { meta, _d -> meta.level == 'L1' }.map { _meta, d -> d }
        ch_ablation_attributions_l2 = ABLATION.out.ablation_attributions_per_level.filter { meta, _d -> meta.level == 'L2' }.map { _meta, d -> d }
        ch_ablation_attributions_l3 = ABLATION.out.ablation_attributions_per_level.filter { meta, _d -> meta.level == 'L3' }.map { _meta, d -> d }

        ch_ablation_null_training_l0 = ABLATION.out.null_training_per_level.filter { meta, _d -> meta.level == 'L0' }.map { _meta, d -> d }
        ch_ablation_null_training_l1 = ABLATION.out.null_training_per_level.filter { meta, _d -> meta.level == 'L1' }.map { _meta, d -> d }
        ch_ablation_null_training_l2 = ABLATION.out.null_training_per_level.filter { meta, _d -> meta.level == 'L2' }.map { _meta, d -> d }
        ch_ablation_null_training_l3 = ABLATION.out.null_training_per_level.filter { meta, _d -> meta.level == 'L3' }.map { _meta, d -> d }

        ch_ablation_null_attributions_l0 = ABLATION.out.null_attributions_per_level.filter { meta, _d -> meta.level == 'L0' }.map { _meta, d -> d }
        ch_ablation_null_attributions_l1 = ABLATION.out.null_attributions_per_level.filter { meta, _d -> meta.level == 'L1' }.map { _meta, d -> d }
        ch_ablation_null_attributions_l2 = ABLATION.out.null_attributions_per_level.filter { meta, _d -> meta.level == 'L2' }.map { _meta, d -> d }
        ch_ablation_null_attributions_l3 = ABLATION.out.null_attributions_per_level.filter { meta, _d -> meta.level == 'L3' }.map { _meta, d -> d }

        ch_ablation_comparison_l0 = ABLATION.out.attribution_comparison_per_level.filter { meta, _s, _d -> meta.level == 'L0' }.map { _meta, summary, dir -> [summary, dir] }
        ch_ablation_comparison_l1 = ABLATION.out.attribution_comparison_per_level.filter { meta, _s, _d -> meta.level == 'L1' }.map { _meta, summary, dir -> [summary, dir] }
        ch_ablation_comparison_l2 = ABLATION.out.attribution_comparison_per_level.filter { meta, _s, _d -> meta.level == 'L2' }.map { _meta, summary, dir -> [summary, dir] }
        ch_ablation_comparison_l3 = ABLATION.out.attribution_comparison_per_level.filter { meta, _s, _d -> meta.level == 'L3' }.map { _meta, summary, dir -> [summary, dir] }

        ch_ablation_comparison_corrected_l0 = ABLATION.out.attribution_comparison_corrected_per_level.filter { meta, _d -> meta.level == 'L0' }.map { _meta, d -> d }
        ch_ablation_comparison_corrected_l1 = ABLATION.out.attribution_comparison_corrected_per_level.filter { meta, _d -> meta.level == 'L1' }.map { _meta, d -> d }
        ch_ablation_comparison_corrected_l2 = ABLATION.out.attribution_comparison_corrected_per_level.filter { meta, _d -> meta.level == 'L2' }.map { _meta, d -> d }
        ch_ablation_comparison_corrected_l3 = ABLATION.out.attribution_comparison_corrected_per_level.filter { meta, _d -> meta.level == 'L3' }.map { _meta, d -> d }

        ch_ablation_bootstrap_l0 = ABLATION.out.bootstrap_calibration_per_level.filter { meta, _f -> meta.level == 'L0' }.map { _meta, f -> f }
        ch_ablation_bootstrap_l1 = ABLATION.out.bootstrap_calibration_per_level.filter { meta, _f -> meta.level == 'L1' }.map { _meta, f -> f }
        ch_ablation_bootstrap_l2 = ABLATION.out.bootstrap_calibration_per_level.filter { meta, _f -> meta.level == 'L2' }.map { _meta, f -> f }
        ch_ablation_bootstrap_l3 = ABLATION.out.bootstrap_calibration_per_level.filter { meta, _f -> meta.level == 'L3' }.map { _meta, f -> f }

        ch_ablation_gene_delta_l0 = ABLATION.out.gene_list_delta_per_level.filter { meta, _f -> meta.level == 'L0' }.map { _meta, f -> f }
        ch_ablation_gene_delta_l1 = ABLATION.out.gene_list_delta_per_level.filter { meta, _f -> meta.level == 'L1' }.map { _meta, f -> f }
        ch_ablation_gene_delta_l2 = ABLATION.out.gene_list_delta_per_level.filter { meta, _f -> meta.level == 'L2' }.map { _meta, f -> f }
        ch_ablation_gene_delta_l3 = ABLATION.out.gene_list_delta_per_level.filter { meta, _f -> meta.level == 'L3' }.map { _meta, f -> f }

        ch_ablation_gene_zattr_l0 = ABLATION.out.gene_list_zattr_per_level.filter { meta, _f -> meta.level == 'L0' }.map { _meta, f -> f }
        ch_ablation_gene_zattr_l1 = ABLATION.out.gene_list_zattr_per_level.filter { meta, _f -> meta.level == 'L1' }.map { _meta, f -> f }
        ch_ablation_gene_zattr_l2 = ABLATION.out.gene_list_zattr_per_level.filter { meta, _f -> meta.level == 'L2' }.map { _meta, f -> f }
        ch_ablation_gene_zattr_l3 = ABLATION.out.gene_list_zattr_per_level.filter { meta, _f -> meta.level == 'L3' }.map { _meta, f -> f }

        ch_ablation_variant_significance_l0 = ABLATION.out.variant_significance_per_level.filter { meta, _f -> meta.level == 'L0' }.map { _meta, f -> f }
        ch_ablation_variant_significance_l1 = ABLATION.out.variant_significance_per_level.filter { meta, _f -> meta.level == 'L1' }.map { _meta, f -> f }
        ch_ablation_variant_significance_l2 = ABLATION.out.variant_significance_per_level.filter { meta, _f -> meta.level == 'L2' }.map { _meta, f -> f }
        ch_ablation_variant_significance_l3 = ABLATION.out.variant_significance_per_level.filter { meta, _f -> meta.level == 'L3' }.map { _meta, f -> f }
    }

    //
    // SUBWORKFLOW: Epistasis — audit co-occurrence, validate, power analysis, gene interactions
    //
    ch_published_epistasis_audit = channel.empty()
    ch_published_gene_interactions = channel.empty()

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
        ch_published_epistasis_audit = EPISTASIS.out.published_explainability_analysis.filter { f ->
            f.toString().contains('epistasis')
        }
        ch_published_gene_interactions = EPISTASIS.out.published_explainability_analysis.filter { f ->
            f.toString().contains('gene_interaction')
        }
    }

    //
    // SUBWORKFLOW: Validation — validate discoveries and collect plots
    //
    ch_published_validation = channel.empty()

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
        ch_published_validation = VALIDATION.out.published_explainability_analysis
            .mix(VALIDATION.out.published_plots)
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
    sex_map                             = ch_published_sex_map
    preprocessed_dataset                = ch_published_preprocessed
    real_training                       = ch_published_best_model
    real_cv_folds                       = ch_published_cv_folds
    real_attributions                   = ch_published_explainability_best
    null_training_l3                    = ch_published_null_model
    null_attributions_l3                = ch_published_null_attributions
    null_comparison_l3                  = ch_published_null_comparison
    null_comparison_corrected_l3        = ch_published_null_comparison_corrected
    bootstrap_calibration_l3            = ch_published_bootstrap_calibration
    gene_list_delta                     = ch_published_gene_list_delta
    gene_list_zattr                     = ch_published_gene_list_zattr
    variant_significance                = ch_published_variant_significance
    ablation_training_l0                = ch_ablation_training_l0
    ablation_training_l1                = ch_ablation_training_l1
    ablation_training_l2                = ch_ablation_training_l2
    ablation_training_l3                = ch_ablation_training_l3
    ablation_attributions_l0            = ch_ablation_attributions_l0
    ablation_attributions_l1            = ch_ablation_attributions_l1
    ablation_attributions_l2            = ch_ablation_attributions_l2
    ablation_attributions_l3            = ch_ablation_attributions_l3
    ablation_null_training_l0           = ch_ablation_null_training_l0
    ablation_null_training_l1           = ch_ablation_null_training_l1
    ablation_null_training_l2           = ch_ablation_null_training_l2
    ablation_null_training_l3           = ch_ablation_null_training_l3
    ablation_null_attributions_l0       = ch_ablation_null_attributions_l0
    ablation_null_attributions_l1       = ch_ablation_null_attributions_l1
    ablation_null_attributions_l2       = ch_ablation_null_attributions_l2
    ablation_null_attributions_l3       = ch_ablation_null_attributions_l3
    ablation_comparison_l0              = ch_ablation_comparison_l0
    ablation_comparison_l1              = ch_ablation_comparison_l1
    ablation_comparison_l2              = ch_ablation_comparison_l2
    ablation_comparison_l3              = ch_ablation_comparison_l3
    ablation_comparison_corrected_l0    = ch_ablation_comparison_corrected_l0
    ablation_comparison_corrected_l1    = ch_ablation_comparison_corrected_l1
    ablation_comparison_corrected_l2    = ch_ablation_comparison_corrected_l2
    ablation_comparison_corrected_l3    = ch_ablation_comparison_corrected_l3
    ablation_bootstrap_l0               = ch_ablation_bootstrap_l0
    ablation_bootstrap_l1               = ch_ablation_bootstrap_l1
    ablation_bootstrap_l2               = ch_ablation_bootstrap_l2
    ablation_bootstrap_l3               = ch_ablation_bootstrap_l3
    ablation_gene_delta_l0              = ch_ablation_gene_delta_l0
    ablation_gene_delta_l1              = ch_ablation_gene_delta_l1
    ablation_gene_delta_l2              = ch_ablation_gene_delta_l2
    ablation_gene_delta_l3              = ch_ablation_gene_delta_l3
    ablation_gene_zattr_l0              = ch_ablation_gene_zattr_l0
    ablation_gene_zattr_l1              = ch_ablation_gene_zattr_l1
    ablation_gene_zattr_l2              = ch_ablation_gene_zattr_l2
    ablation_gene_zattr_l3              = ch_ablation_gene_zattr_l3
    ablation_variant_significance_l0    = ch_ablation_variant_significance_l0
    ablation_variant_significance_l1    = ch_ablation_variant_significance_l1
    ablation_variant_significance_l2    = ch_ablation_variant_significance_l2
    ablation_variant_significance_l3    = ch_ablation_variant_significance_l3
    ablation_comparison_summary         = ch_published_ablation_comparison
    epistasis_audit                     = ch_published_epistasis_audit
    gene_interactions                   = ch_published_gene_interactions
    validation                          = ch_published_validation
    pipeline_versions                   = ch_collated_versions
    versions                            = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
