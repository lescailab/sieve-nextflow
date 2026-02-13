/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

include { SIEVE_INFER_SEX } from '../modules/local/sieve/infer_sex/main'
include { SIEVE_PREPROCESS } from '../modules/local/sieve/preprocess/main'
include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_GRID } from '../modules/local/sieve/train_single/main'
include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_ABLATION } from '../modules/local/sieve/train_single/main'
include { SIEVE_TRAIN_SINGLE as SIEVE_TRAIN_SINGLE_NULL } from '../modules/local/sieve/train_single/main'
include { SIEVE_TRAIN_CV } from '../modules/local/sieve/train_cv/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_REAL } from '../modules/local/sieve/explain/main'
include { SIEVE_EXPLAIN as SIEVE_EXPLAIN_NULL } from '../modules/local/sieve/explain/main'
include { SIEVE_CREATE_NULL_BASELINE } from '../modules/local/sieve/create_null_baseline/main'
include { SIEVE_COMPARE_ATTRIBUTIONS as SIEVE_COMPARE_ATTRIBUTIONS_RAW } from '../modules/local/sieve/compare_attributions/main'
include { SIEVE_COMPARE_ATTRIBUTIONS as SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED } from '../modules/local/sieve/compare_attributions/main'
include { SIEVE_VALIDATE_EPISTASIS } from '../modules/local/sieve/validate_epistasis/main'
include { SIEVE_VALIDATE_DISCOVERIES } from '../modules/local/sieve/validate_discoveries/main'
include { SIEVE_SELECT_BEST_PARAMS } from '../modules/local/sieve/select_best_params/main'
include { SIEVE_SELECT_BEST_CHECKPOINT } from '../modules/local/sieve/select_best_checkpoint/main'
include { SIEVE_ABLATION_COMPARE } from '../modules/local/sieve/ablation_compare/main'
include { SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS } from '../modules/local/sieve/filter_sex_chrom_attributions/main'
include { SIEVE_COLLECT_PLOTS } from '../modules/local/sieve/collect_plots/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SIEVE {

    main:

    ch_versions = Channel.empty()
    ch_plot_sources = Channel.empty()

    def cohortMeta = [id: params.cohort_id ?: 'cohort']
    def ch_selection_meta = Channel.value([id: cohortMeta.id])

    def selectedSteps = resolveExecuteSteps(params.execute_step)
    log.info("Executing SIEVE steps: ${selectedSteps.join(', ')}")

    def targetSex = selectedSteps.contains('sex')
    def targetPreprocess = selectedSteps.contains('preprocess')
    def targetGrid = selectedSteps.contains('grid')
    def targetCv = selectedSteps.contains('cv')
    def targetExplain = selectedSteps.contains('explain')
    def targetAblation = selectedSteps.contains('ablation')
    def targetNull = selectedSteps.contains('null')
    def targetEpistasis = selectedSteps.contains('epistasis')
    def targetValidation = selectedSteps.contains('validation')
    def targetPlots = selectedSteps.contains('plots')

    def useProvidedSexMap = params.sex_map as boolean
    def useProvidedPreprocessed = params.preprocessed_data as boolean
    def useProvidedBestParams = params.best_params as boolean
    def useProvidedBestCheckpoint = (params.best_checkpoint && params.checkpoint_config) as boolean

    def needExplain = targetExplain || targetEpistasis || targetValidation || targetNull
    def needBestCheckpoint = targetCv || needExplain
    def needBestParams = targetGrid || targetAblation || targetNull || (needBestCheckpoint && !useProvidedBestCheckpoint)
    def needPreprocessed = targetPreprocess || needBestParams || needExplain || (needBestCheckpoint && !useProvidedBestCheckpoint)
    def needSexMap = targetSex || needBestParams || (needPreprocessed && !useProvidedPreprocessed)

    ch_effective_sex_map = Channel.empty()

    if (needSexMap) {
        if (useProvidedSexMap) {
            ch_effective_sex_map = Channel.value(
                tuple(
                    cohortMeta,
                    file(params.sex_map, checkIfExists: true)
                )
            )
        } else {
            if (!params.infer_sex) {
                error('The selected steps require a sex map. Provide --sex_map or set --infer_sex true.')
            }

            ch_vcf_for_sex = Channel
                .fromPath(params.vcf, checkIfExists: true)
                .map { vcf -> tuple(cohortMeta, vcf) }

            SIEVE_INFER_SEX(
                ch_vcf_for_sex,
                params.genome_build
            )
            ch_effective_sex_map = SIEVE_INFER_SEX.out.sex_map
            ch_versions = ch_versions.mix(SIEVE_INFER_SEX.out.versions)
            ch_plot_sources = ch_plot_sources.mix(SIEVE_INFER_SEX.out.diagnostics.map { meta, diagnostic -> diagnostic })
        }
    }

    ch_preprocessed = Channel.empty()

    if (needPreprocessed) {
        if (useProvidedPreprocessed) {
            ch_preprocessed = Channel.value(
                tuple(
                    cohortMeta,
                    file(params.preprocessed_data, checkIfExists: true)
                )
            )
        } else {
            ch_vcf_for_preprocess = Channel
                .fromPath(params.vcf, checkIfExists: true)
                .map { vcf -> tuple(cohortMeta, vcf) }

            ch_phenotypes = Channel
                .fromPath(params.phenotypes, checkIfExists: true)
                .map { phenotypes -> tuple(cohortMeta, phenotypes) }

            ch_preprocess_input = ch_vcf_for_preprocess
                .combine(ch_phenotypes, by: 0)
                .combine(ch_effective_sex_map, by: 0)
                .map { meta, vcf, phenotypes, sex_map ->
                    tuple(meta, vcf, phenotypes, sex_map)
                }

            SIEVE_PREPROCESS(
                ch_preprocess_input,
                params.genome_build
            )
            ch_versions = ch_versions.mix(SIEVE_PREPROCESS.out.versions)
            ch_preprocessed = SIEVE_PREPROCESS.out.preprocessed
        }
    }

    ch_preprocessed_keyed = ch_preprocessed.map { meta, preprocessed ->
        tuple(meta.id, preprocessed)
    }

    ch_sex_map_keyed = ch_effective_sex_map.map { meta, sex_map ->
        tuple(meta.id, sex_map)
    }

    def baseTrainingParams = [
        epochs: params.train_epochs as Integer,
        batch_size: params.train_batch_size as Integer,
        chunk_size: params.train_chunk_size as Integer,
        aggregation_method: params.train_aggregation_method,
        gradient_accumulation_steps: params.train_gradient_accumulation_steps as Integer,
        gradient_clip: params.train_gradient_clip as Double,
        seed: params.train_seed as Integer,
        device: params.train_device,
        early_stopping: params.train_early_stopping as Integer,
        hidden_dim: params.train_hidden_dim as Integer,
        num_attention_layers: params.train_num_attention_layers as Integer,
    ].findAll { key, value -> value != null }

    ch_best_params_path_keyed = Channel.empty()
    ch_best_params_map_keyed = Channel.empty()

    if (needBestParams) {
        if (useProvidedBestParams) {
            ch_best_params_path_keyed = Channel.value(
                tuple(
                    cohortMeta.id,
                    file(params.best_params, checkIfExists: true)
                )
            )
        } else if (useProvidedBestCheckpoint) {
            ch_best_params_path_keyed = Channel.value(
                tuple(
                    cohortMeta.id,
                    file(params.checkpoint_config, checkIfExists: true)
                )
            )
        } else {
            def trainingGrid = buildTrainingGrid(
                baseTrainingParams,
                params.grid_lr,
                params.grid_lambda_attr,
                params.grid_latent_dim,
                params.grid_hidden_dim,
                params.grid_num_attention_layers
            )

            ch_grid_specs = Channel
                .fromList(trainingGrid)
                .map { grid_params ->
                    tuple(
                        cohortMeta.id,
                        [id: cohortMeta.id, run_id: grid_params.run_id, stage: 'grid', level: params.default_train_level],
                        grid_params,
                        params.default_train_level,
                        params.val_split
                    )
                }

            ch_grid_train_input = ch_grid_specs
                .join(ch_preprocessed_keyed, by: 0)
                .join(ch_sex_map_keyed, by: 0)
                .map { key, meta, grid_params, level, val_split, preprocessed, sex_map ->
                    tuple(meta, preprocessed, sex_map, grid_params, level, val_split)
                }

            SIEVE_TRAIN_SINGLE_GRID(ch_grid_train_input)
            ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_GRID.out.versions)

            ch_grid_selection_dirs = SIEVE_TRAIN_SINGLE_GRID.out.selection_payload
                .map { meta, run_dir -> run_dir }
                .collect()

            SIEVE_SELECT_BEST_PARAMS(
                ch_selection_meta,
                ch_grid_selection_dirs
            )
            ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_PARAMS.out.versions)

            ch_best_params_path_keyed = SIEVE_SELECT_BEST_PARAMS.out.best_params.map { meta, best_params, best_run_id, summary ->
                tuple(meta.id, best_params)
            }
        }

        ch_best_params_map_keyed = ch_best_params_path_keyed.map { cohort_id, best_params_path ->
            tuple(cohort_id, extractTrainingParams(best_params_path))
        }
    }

    ch_best_checkpoint_keyed = Channel.empty()
    ch_published_best_model = Channel.empty()

    if (needBestCheckpoint) {
        if (useProvidedBestCheckpoint) {
            ch_best_checkpoint_keyed = Channel.value(
                tuple(
                    cohortMeta.id,
                    file(params.best_checkpoint, checkIfExists: true),
                    file(params.checkpoint_config, checkIfExists: true)
                )
            )

            ch_published_best_model = ch_best_checkpoint_keyed.map { cohort_id, checkpoint, config ->
                [checkpoint, config]
            }
        } else {
            ch_cv_spec = Channel.value(
                tuple(
                    cohortMeta.id,
                    [id: cohortMeta.id, run_id: 'cv_main', stage: 'cv', level: params.default_train_level],
                    params.default_train_level,
                    params.cv_folds
                )
            )

            ch_cv_input = ch_cv_spec
                .join(ch_preprocessed_keyed, by: 0)
                .join(ch_sex_map_keyed, by: 0)
                .join(ch_best_params_path_keyed, by: 0)
                .map { key, meta, level, cv_folds, preprocessed, sex_map, best_params ->
                    tuple(meta, preprocessed, sex_map, best_params, level, cv_folds)
                }

            SIEVE_TRAIN_CV(ch_cv_input)
            ch_versions = ch_versions.mix(SIEVE_TRAIN_CV.out.versions)
            ch_plot_sources = ch_plot_sources.mix(SIEVE_TRAIN_CV.out.cv_bundle.map { meta, cv_output, cv_results -> cv_output })

            SIEVE_SELECT_BEST_CHECKPOINT(SIEVE_TRAIN_CV.out.cv_bundle)
            ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_CHECKPOINT.out.versions)

            ch_best_checkpoint_keyed = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { meta, checkpoint, config, fold_id, summary ->
                tuple(meta.id, checkpoint, config)
            }

            ch_published_best_model = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { meta, checkpoint, fold_config, fold_id, cv_summary ->
                [checkpoint, fold_config, fold_id, cv_summary]
            }
        }
    }

    ch_real_rankings = Channel.empty()
    ch_real_variant_keyed = Channel.empty()
    ch_published_explainability_best = Channel.empty()

    if (needExplain) {
        ch_explain_real_input = ch_best_checkpoint_keyed
            .join(ch_preprocessed_keyed, by: 0)
            .map { key, checkpoint, config, preprocessed ->
                tuple([id: key, run_id: 'explain_real', stage: 'explain', level: params.default_train_level], checkpoint, config, preprocessed, false)
            }

        SIEVE_EXPLAIN_REAL(ch_explain_real_input)
        ch_versions = ch_versions.mix(SIEVE_EXPLAIN_REAL.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_EXPLAIN_REAL.out.explain_dir.map { meta, explain_dir -> explain_dir })

        ch_real_rankings = SIEVE_EXPLAIN_REAL.out.rankings
        ch_real_variant_keyed = ch_real_rankings.map { meta, variant_rankings, gene_rankings, interactions ->
            tuple(meta.id, variant_rankings)
        }
        ch_published_explainability_best = SIEVE_EXPLAIN_REAL.out.explain_dir.map { meta, explain_dir ->
            explain_dir
        }
    }

    ch_published_ablation_discovery = Channel.empty()

    if (targetAblation) {
        ch_ablation_specs = Channel
            .fromList(['L0', 'L1', 'L2', 'L3'])
            .map { level ->
                tuple(
                    cohortMeta.id,
                    [id: cohortMeta.id, run_id: "ablation_${level}", stage: 'ablation', level: level],
                    level,
                    params.val_split
                )
            }

        ch_ablation_train_input = ch_ablation_specs
            .join(ch_preprocessed_keyed, by: 0)
            .join(ch_sex_map_keyed, by: 0)
            .join(ch_best_params_map_keyed, by: 0)
            .map { key, meta, level, val_split, preprocessed, sex_map, best_params_map ->
                def ablationParams = new LinkedHashMap(baseTrainingParams)
                ablationParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
                ablationParams.put('annotation_level', level)
                tuple(meta, preprocessed, sex_map, ablationParams, level, val_split)
            }

        SIEVE_TRAIN_SINGLE_ABLATION(ch_ablation_train_input)
        ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_ABLATION.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { meta, run_dir -> run_dir })

        ch_ablation_selection_dirs = SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload
            .map { meta, run_dir -> run_dir }
            .collect()

        SIEVE_ABLATION_COMPARE(
            ch_selection_meta,
            ch_ablation_selection_dirs
        )
        ch_versions = ch_versions.mix(SIEVE_ABLATION_COMPARE.out.versions)

        ch_published_ablation_discovery = SIEVE_ABLATION_COMPARE.out.ablation_summary
            .map { meta, ablation_tsv, ablation_yaml ->
                [ablation_tsv, ablation_yaml]
            }
            .mix(
                SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { meta, run_dir ->
                    run_dir
                }
            )
    }

    ch_published_null_model = Channel.empty()
    ch_published_null_comparison = Channel.empty()
    ch_published_null_comparison_sex_fixed = Channel.empty()

    if (targetNull) {
        ch_null_baseline_input = ch_preprocessed_keyed.map { cohort_id, preprocessed ->
            tuple([id: cohort_id, run_id: 'null_baseline_dataset', stage: 'null_baseline'], preprocessed, params.null_seed)
        }

        SIEVE_CREATE_NULL_BASELINE(ch_null_baseline_input)
        ch_versions = ch_versions.mix(SIEVE_CREATE_NULL_BASELINE.out.versions)

        ch_null_preprocessed_keyed = SIEVE_CREATE_NULL_BASELINE.out.null_preprocessed.map { meta, preprocessed_null ->
            tuple(meta.id, preprocessed_null)
        }

        ch_null_train_spec = Channel.value(
            tuple(
                cohortMeta.id,
                [id: cohortMeta.id, run_id: 'null_train', stage: 'null_baseline', level: params.default_train_level],
                params.default_train_level,
                params.val_split
            )
        )

        ch_null_train_input = ch_null_train_spec
            .join(ch_null_preprocessed_keyed, by: 0)
            .join(ch_sex_map_keyed, by: 0)
            .join(ch_best_params_map_keyed, by: 0)
            .map { key, meta, level, val_split, preprocessed_null, sex_map, best_params_map ->
                def nullParams = new LinkedHashMap(baseTrainingParams)
                nullParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
                nullParams.put('annotation_level', level)
                tuple(meta, preprocessed_null, sex_map, nullParams, level, val_split)
            }

        SIEVE_TRAIN_SINGLE_NULL(ch_null_train_input)
        ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_NULL.out.versions)

        ch_null_model_keyed = SIEVE_TRAIN_SINGLE_NULL.out.train_artifacts.map { meta, results, config, model ->
            tuple(meta.id, model, config)
        }

        ch_null_explain_input = ch_null_model_keyed
            .join(ch_null_preprocessed_keyed, by: 0)
            .map { key, checkpoint, config, preprocessed_null ->
                tuple([id: key, run_id: 'explain_null', stage: 'null_baseline', level: params.default_train_level], checkpoint, config, preprocessed_null, true)
            }

        SIEVE_EXPLAIN_NULL(ch_null_explain_input)
        ch_versions = ch_versions.mix(SIEVE_EXPLAIN_NULL.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_EXPLAIN_NULL.out.explain_dir.map { meta, explain_dir -> explain_dir })

        ch_null_variant_keyed = SIEVE_EXPLAIN_NULL.out.rankings.map { meta, variant_rankings, gene_rankings, interactions ->
            tuple(meta.id, variant_rankings)
        }

        ch_compare_attributions_input = ch_real_variant_keyed
            .join(ch_null_variant_keyed, by: 0)
            .map { key, real_variant_rankings, null_variant_rankings ->
                tuple([id: key, run_id: 'compare_attributions', stage: 'null_baseline'], real_variant_rankings, null_variant_rankings)
            }

        SIEVE_COMPARE_ATTRIBUTIONS_RAW(ch_compare_attributions_input)
        ch_versions = ch_versions.mix(SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.comparison.map { meta, summary, comparison_dir -> comparison_dir })

        ch_sex_fixed_filter_input = ch_real_variant_keyed
            .join(ch_null_variant_keyed, by: 0)
            .map { key, real_variant_rankings, null_variant_rankings ->
                tuple([id: key, run_id: 'sex_chr_filter', stage: 'null_baseline'], real_variant_rankings, null_variant_rankings)
            }

        SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS(ch_sex_fixed_filter_input)
        ch_versions = ch_versions.mix(SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS.out.versions)

        ch_compare_sex_fixed_input = SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS.out.filtered_rankings.map { meta, real_autosomal, null_autosomal, filter_summary ->
            tuple([id: meta.id, run_id: 'compare_attributions_sex_fixed', stage: 'null_baseline'], real_autosomal, null_autosomal)
        }

        SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED(ch_compare_sex_fixed_input)
        ch_versions = ch_versions.mix(SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED.out.comparison.map { meta, summary, comparison_dir -> comparison_dir })

        ch_published_null_model = SIEVE_TRAIN_SINGLE_NULL.out.train_artifacts
            .map { meta, null_results, null_config, null_model ->
                [null_model, null_config, null_results]
            }
            .mix(
                SIEVE_TRAIN_SINGLE_NULL.out.history.map { meta, null_history ->
                    null_history
                }
            )
            .mix(
                SIEVE_CREATE_NULL_BASELINE.out.null_preprocessed.map { meta, null_preprocessed ->
                    null_preprocessed
                }
            )
            .mix(
                SIEVE_EXPLAIN_NULL.out.explain_dir.map { meta, null_explain_dir ->
                    null_explain_dir
                }
            )

        ch_published_null_comparison = SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.comparison.map { meta, comparison_summary, comparison_dir ->
            [comparison_summary, comparison_dir]
        }

        ch_published_null_comparison_sex_fixed = SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED.out.comparison
            .map { meta, comparison_summary, comparison_dir ->
                [comparison_summary, comparison_dir]
            }
            .mix(
                SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS.out.filtered_rankings.map { meta, real_autosomal, null_autosomal, filter_summary ->
                    [real_autosomal, null_autosomal, filter_summary]
                }
            )
    }

    ch_published_explainability_analysis = Channel.empty()

    if (targetEpistasis) {
        ch_nonempty_interactions_keyed = ch_real_rankings
            .map { meta, variant_rankings, gene_rankings, interactions ->
                tuple(meta.id, interactions)
            }
            .filter { cohort_id, interactions ->
                interactions.exists() && interactions.size() > 0 && interactions.readLines().findAll { line -> line.trim() }.size() > 1
            }

        ch_epistasis_input = ch_nonempty_interactions_keyed
            .join(ch_best_checkpoint_keyed, by: 0)
            .join(ch_preprocessed_keyed, by: 0)
            .map { key, interactions, checkpoint, config, preprocessed ->
                tuple([id: key, run_id: 'epistasis_validation', stage: 'epistasis'], interactions, checkpoint, config, preprocessed)
            }

        SIEVE_VALIDATE_EPISTASIS(ch_epistasis_input)
        ch_versions = ch_versions.mix(SIEVE_VALIDATE_EPISTASIS.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_VALIDATE_EPISTASIS.out.epistasis.map { meta, epistasis_csv, epistasis_dir -> epistasis_dir })

        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
            SIEVE_VALIDATE_EPISTASIS.out.epistasis.map { meta, epistasis_validation, epistasis_dir ->
                [epistasis_validation, epistasis_dir]
            }
        )
    }

    if (targetValidation) {
        ch_discovery_validation_input = ch_real_rankings.map { meta, variant_rankings, gene_rankings, interactions ->
            tuple(
                [id: meta.id, run_id: 'discoveries_validation', stage: 'validation'],
                variant_rankings,
                gene_rankings,
                params.clinvar_tsv,
                params.gwas_tsv,
                params.go_mapping_json
            )
        }

        SIEVE_VALIDATE_DISCOVERIES(ch_discovery_validation_input)
        ch_versions = ch_versions.mix(SIEVE_VALIDATE_DISCOVERIES.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_VALIDATE_DISCOVERIES.out.validation.map { meta, validation_report, validation_dir -> validation_dir })

        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
            SIEVE_VALIDATE_DISCOVERIES.out.validation.map { meta, validation_report, validation_dir ->
                [validation_report, validation_dir]
            }
        )
    }

    ch_published_plots = Channel.empty()

    if (targetPlots) {
        ch_plot_sources_list = ch_plot_sources.collect()

        SIEVE_COLLECT_PLOTS(
            ch_selection_meta,
            ch_plot_sources_list
        )
        ch_versions = ch_versions.mix(SIEVE_COLLECT_PLOTS.out.versions)

        ch_published_plots = SIEVE_COLLECT_PLOTS.out.plot_bundle.map { meta, plots_dir, plots_manifest ->
            [plots_dir, plots_manifest]
        }
    }

    softwareVersionsToYAML(ch_versions)
        .collectFile(
            name: 'nf_core_sieve_software_versions.yml',
            sort: true,
            newLine: true
        )
        .set { ch_collated_versions }

    ch_published_sex_map = ch_effective_sex_map.map { meta, sex_map_file ->
        sex_map_file
    }

    ch_published_preprocessed = ch_preprocessed.map { meta, preprocessed_file ->
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
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def splitCsvValues(value) {
    if (value == null) {
        return []
    }
    if (value instanceof List) {
        return value
    }
    return value
        .toString()
        .split(',')
        .collect { it.trim() }
        .findAll { it }
}

def executionStepNames() {
    return [
        'sex',
        'preprocess',
        'grid',
        'cv',
        'explain',
        'ablation',
        'null',
        'epistasis',
        'validation',
        'plots',
    ] as LinkedHashSet
}

def normalizeExecutionStep(rawStep) {
    if (rawStep == null) {
        return null
    }

    def step = rawStep
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(/[\s-]+/, '_')

    switch (step) {
        case 'all':
            return 'all'
        case 'sex':
        case 'sex_map':
        case 'infer_sex':
            return 'sex'
        case 'preprocess':
        case 'preprocessing':
        case 'preprocessed':
            return 'preprocess'
        case 'grid':
        case 'grid_search':
        case 'best_params':
        case 'hyperparameter_search':
            return 'grid'
        case 'cv':
        case 'cross_fold':
        case 'cross_validation':
        case 'checkpoint_selection':
            return 'cv'
        case 'explain':
        case 'explainability':
            return 'explain'
        case 'ablation':
        case 'ablation_experiment':
            return 'ablation'
        case 'null':
        case 'null_model':
        case 'null_baseline':
            return 'null'
        case 'epistasis':
        case 'epistasis_validation':
            return 'epistasis'
        case 'validation':
        case 'discoveries':
        case 'discovery_validation':
            return 'validation'
        case 'plots':
        case 'collect_plots':
            return 'plots'
        default:
            return step
    }
}

def resolveExecuteSteps(stepValue) {
    def allSteps = executionStepNames()
    def requested = splitCsvValues(stepValue)
        .collect { normalizeExecutionStep(it) }
        .findAll { it }

    if (!requested) {
        return allSteps
    }

    if (requested.contains('all')) {
        return allSteps
    }

    def invalid = requested.findAll { !(it in allSteps) }.unique()
    if (invalid) {
        throw new IllegalArgumentException("Invalid --execute_step value(s): ${invalid.join(', ')}. Allowed values: ${allSteps.join(', ')}")
    }

    return requested as LinkedHashSet
}

def extractTrainingParams(configPath) {
    def allowedKeys = [
        'epochs',
        'batch_size',
        'chunk_size',
        'aggregation_method',
        'gradient_accumulation_steps',
        'gradient_clip',
        'seed',
        'device',
        'early_stopping',
        'hidden_dim',
        'num_attention_layers',
        'lr',
        'lambda_attr',
        'latent_dim',
        'annotation_level',
        'num_heads',
        'num_workers',
        'max_variants_per_batch',
    ] as Set

    def yaml = new org.yaml.snakeyaml.Yaml()
    def parsed = yaml.load(new File(configPath.toString()).text)
    parsed = parsed instanceof Map ? parsed : [:]

    if (parsed.hyperparameters instanceof Map) {
        parsed = parsed.hyperparameters
    }

    def trainingParams = [:]
    parsed.each { key, value ->
        if (value != null) {
            def normalizedKey = key.toString().replace('-', '_')
            if (normalizedKey in allowedKeys) {
                trainingParams[normalizedKey] = value
            }
        }
    }

    return trainingParams
}

def buildTrainingGrid(baseTrainParams, lrValues, lambdaAttrValues, latentDimValues, hiddenDimValues, layerValues) {
    def lrList = splitCsvValues(lrValues).collect { it as Double }
    def lambdaList = splitCsvValues(lambdaAttrValues).collect { it as Double }
    def latentList = splitCsvValues(latentDimValues).collect { it as Integer }
    def hiddenList = splitCsvValues(hiddenDimValues).collect { it as Integer }
    def layerList = splitCsvValues(layerValues).collect { it as Integer }

    if (!lrList || !lambdaList || !latentList || !hiddenList || !layerList) {
        def missing = []
        if (!lrList) missing << 'grid_lr'
        if (!lambdaList) missing << 'grid_lambda_attr'
        if (!latentList) missing << 'grid_latent_dim'
        if (!hiddenList) missing << 'grid_hidden_dim'
        if (!layerList) missing << 'grid_num_attention_layers'
        throw new IllegalArgumentException("Training grid values cannot be empty: ${missing.join(', ')}")
    }

    def grid = []
    int runCounter = 0

    lrList.each { lr ->
        lambdaList.each { lambda_attr ->
            latentList.each { latent_dim ->
                hiddenList.each { hidden_dim ->
                    layerList.each { num_attention_layers ->
                        runCounter += 1
                        def runParams = new LinkedHashMap(baseTrainParams ?: [:])
                        runParams.putAll([
                            run_id: String.format('grid_%03d', runCounter),
                            lr: lr,
                            lambda_attr: lambda_attr,
                            latent_dim: latent_dim,
                            hidden_dim: hidden_dim,
                            num_attention_layers: num_attention_layers,
                        ])
                        grid << runParams
                    }
                }
            }
        }
    }

    return grid
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
