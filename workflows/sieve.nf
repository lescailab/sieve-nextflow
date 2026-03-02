/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
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

    def selectedSteps = SieveStepUtils.resolveExecuteSteps(params.execute_step)
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
            ch_plot_sources = ch_plot_sources.mix(SIEVE_INFER_SEX.out.diagnostics.map { _meta, diagnostic -> diagnostic })
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
    ].findAll { _key, value -> value != null }

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
            def trainingGrid = SieveTrainingUtils.buildTrainingGrid(
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
                .combine(ch_preprocessed_keyed, by: 0)
                .combine(ch_sex_map_keyed, by: 0)
                .map { _key, meta, grid_params, level, val_split, preprocessed, sex_map ->
                    tuple(meta, preprocessed, sex_map, grid_params, level, val_split)
                }

            SIEVE_TRAIN_SINGLE_GRID(ch_grid_train_input)
            ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_GRID.out.versions)

            ch_grid_selection_dirs = SIEVE_TRAIN_SINGLE_GRID.out.selection_payload
                .map { _meta, run_dir -> run_dir }
                .collect()

            SIEVE_SELECT_BEST_PARAMS(
                ch_selection_meta,
                ch_grid_selection_dirs
            )
            ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_PARAMS.out.versions)

            ch_best_params_path_keyed = SIEVE_SELECT_BEST_PARAMS.out.best_params.map { meta, best_params, _best_run_id, _summary ->
                tuple(meta.id, best_params)
            }
        }

        ch_best_params_map_keyed = ch_best_params_path_keyed.map { cohort_id, best_params_path ->
            tuple(cohort_id, SieveTrainingUtils.extractTrainingParams(best_params_path))
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

            ch_published_best_model = ch_best_checkpoint_keyed.map { _cohort_id, checkpoint, config ->
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
                .map { _key, meta, level, cv_folds, preprocessed, sex_map, best_params ->
                    tuple(meta, preprocessed, sex_map, best_params, level, cv_folds)
                }

            SIEVE_TRAIN_CV(ch_cv_input)
            ch_versions = ch_versions.mix(SIEVE_TRAIN_CV.out.versions)
            ch_plot_sources = ch_plot_sources.mix(SIEVE_TRAIN_CV.out.cv_bundle.map { _meta, cv_output, _cv_results -> cv_output })

            SIEVE_SELECT_BEST_CHECKPOINT(SIEVE_TRAIN_CV.out.cv_bundle)
            ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_CHECKPOINT.out.versions)

            ch_best_checkpoint_keyed = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { meta, checkpoint, config, _fold_id, _summary ->
                tuple(meta.id, checkpoint, config)
            }

            ch_published_best_model = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { _meta, checkpoint, fold_config, fold_id, cv_summary ->
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
        ch_plot_sources = ch_plot_sources.mix(SIEVE_EXPLAIN_REAL.out.explain_dir.map { _meta, explain_dir -> explain_dir })

        ch_real_rankings = SIEVE_EXPLAIN_REAL.out.rankings
        ch_real_variant_keyed = ch_real_rankings.map { meta, variant_rankings, _gene_rankings, _interactions ->
            tuple(meta.id, variant_rankings)
        }
        ch_published_explainability_best = SIEVE_EXPLAIN_REAL.out.explain_dir.map { _meta, explain_dir ->
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
            .combine(ch_preprocessed_keyed, by: 0)
            .combine(ch_sex_map_keyed, by: 0)
            .combine(ch_best_params_map_keyed, by: 0)
            .map { _key, meta, level, val_split, preprocessed, sex_map, best_params_map ->
                def ablationParams = new LinkedHashMap(baseTrainingParams)
                ablationParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
                ablationParams.put('annotation_level', level)
                tuple(meta, preprocessed, sex_map, ablationParams, level, val_split)
            }

        SIEVE_TRAIN_SINGLE_ABLATION(ch_ablation_train_input)
        ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_ABLATION.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { _meta, run_dir -> run_dir })

        ch_ablation_selection_dirs = SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload
            .map { _meta, run_dir -> run_dir }
            .collect()

        SIEVE_ABLATION_COMPARE(
            ch_selection_meta,
            ch_ablation_selection_dirs
        )
        ch_versions = ch_versions.mix(SIEVE_ABLATION_COMPARE.out.versions)

        ch_published_ablation_discovery = SIEVE_ABLATION_COMPARE.out.ablation_summary
            .map { _meta, ablation_tsv, ablation_yaml ->
                [ablation_tsv, ablation_yaml]
            }
            .mix(
                SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { _meta, run_dir ->
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
            .map { _key, meta, level, val_split, preprocessed_null, sex_map, best_params_map ->
                def nullParams = new LinkedHashMap(baseTrainingParams)
                nullParams.putAll(best_params_map instanceof Map ? best_params_map : [:])
                nullParams.put('annotation_level', level)
                tuple(meta, preprocessed_null, sex_map, nullParams, level, val_split)
            }

        SIEVE_TRAIN_SINGLE_NULL(ch_null_train_input)
        ch_versions = ch_versions.mix(SIEVE_TRAIN_SINGLE_NULL.out.versions)

        ch_null_model_keyed = SIEVE_TRAIN_SINGLE_NULL.out.train_artifacts.map { meta, _results, config, model ->
            tuple(meta.id, model, config)
        }

        ch_null_explain_input = ch_null_model_keyed
            .join(ch_null_preprocessed_keyed, by: 0)
            .map { key, checkpoint, config, preprocessed_null ->
                tuple([id: key, run_id: 'explain_null', stage: 'null_baseline', level: params.default_train_level], checkpoint, config, preprocessed_null, true)
            }

        SIEVE_EXPLAIN_NULL(ch_null_explain_input)
        ch_versions = ch_versions.mix(SIEVE_EXPLAIN_NULL.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_EXPLAIN_NULL.out.explain_dir.map { _meta, explain_dir -> explain_dir })

        ch_null_variant_keyed = SIEVE_EXPLAIN_NULL.out.rankings.map { meta, variant_rankings, _gene_rankings, _interactions ->
            tuple(meta.id, variant_rankings)
        }

        ch_compare_attributions_input = ch_real_variant_keyed
            .join(ch_null_variant_keyed, by: 0)
            .map { key, real_variant_rankings, null_variant_rankings ->
                tuple([id: key, run_id: 'compare_attributions', stage: 'null_baseline'], real_variant_rankings, null_variant_rankings)
            }

        SIEVE_COMPARE_ATTRIBUTIONS_RAW(ch_compare_attributions_input)
        ch_versions = ch_versions.mix(SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.comparison.map { _meta, _summary, comparison_dir -> comparison_dir })

        ch_sex_fixed_filter_input = ch_real_variant_keyed
            .join(ch_null_variant_keyed, by: 0)
            .map { key, real_variant_rankings, null_variant_rankings ->
                tuple([id: key, run_id: 'sex_chr_filter', stage: 'null_baseline'], real_variant_rankings, null_variant_rankings)
            }

        SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS(ch_sex_fixed_filter_input)
        ch_versions = ch_versions.mix(SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS.out.versions)

        ch_compare_sex_fixed_input = SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS.out.filtered_rankings.map { meta, real_autosomal, null_autosomal, _filter_summary ->
            tuple([id: meta.id, run_id: 'compare_attributions_sex_fixed', stage: 'null_baseline'], real_autosomal, null_autosomal)
        }

        SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED(ch_compare_sex_fixed_input)
        ch_versions = ch_versions.mix(SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED.out.comparison.map { _meta, _summary, comparison_dir -> comparison_dir })

        ch_published_null_model = SIEVE_TRAIN_SINGLE_NULL.out.train_artifacts
            .map { _meta, null_results, null_config, null_model ->
                [null_model, null_config, null_results]
            }
            .mix(
                SIEVE_TRAIN_SINGLE_NULL.out.history.map { _meta, null_history ->
                    null_history
                }
            )
            .mix(
                SIEVE_CREATE_NULL_BASELINE.out.null_preprocessed.map { _meta, null_preprocessed ->
                    null_preprocessed
                }
            )
            .mix(
                SIEVE_EXPLAIN_NULL.out.explain_dir.map { _meta, null_explain_dir ->
                    null_explain_dir
                }
            )

        ch_published_null_comparison = SIEVE_COMPARE_ATTRIBUTIONS_RAW.out.comparison.map { _meta, comparison_summary, comparison_dir ->
            [comparison_summary, comparison_dir]
        }

        ch_published_null_comparison_sex_fixed = SIEVE_COMPARE_ATTRIBUTIONS_SEX_FIXED.out.comparison
            .map { _meta, comparison_summary, comparison_dir ->
                [comparison_summary, comparison_dir]
            }
            .mix(
                SIEVE_FILTER_SEX_CHROM_ATTRIBUTIONS.out.filtered_rankings.map { _meta, real_autosomal, null_autosomal, filter_summary ->
                    [real_autosomal, null_autosomal, filter_summary]
                }
            )
    }

    ch_published_explainability_analysis = Channel.empty()

    if (targetEpistasis) {
        ch_nonempty_interactions_keyed = ch_real_rankings
            .map { meta, _variant_rankings, _gene_rankings, interactions ->
                tuple(meta.id, interactions)
            }
            .filter { _cohort_id, interactions ->
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
        ch_plot_sources = ch_plot_sources.mix(SIEVE_VALIDATE_EPISTASIS.out.epistasis.map { _meta, _epistasis_csv, epistasis_dir -> epistasis_dir })

        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
            SIEVE_VALIDATE_EPISTASIS.out.epistasis.map { _meta, epistasis_validation, epistasis_dir ->
                [epistasis_validation, epistasis_dir]
            }
        )
    }

    if (targetValidation) {
        ch_discovery_validation_input = ch_real_rankings.map { meta, variant_rankings, gene_rankings, _interactions ->
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
        ch_plot_sources = ch_plot_sources.mix(SIEVE_VALIDATE_DISCOVERIES.out.validation.map { _meta, _validation_report, validation_dir -> validation_dir })

        ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
            SIEVE_VALIDATE_DISCOVERIES.out.validation.map { _meta, validation_report, validation_dir ->
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

        ch_published_plots = SIEVE_COLLECT_PLOTS.out.plot_bundle.map { _meta, plots_dir, plots_manifest ->
            [plots_dir, plots_manifest]
        }
    }

    NfcoreTemplateUtils.softwareVersionsToYAML(ch_versions, workflow)
        .collectFile(
            name: 'nf_core_sieve_software_versions.yml',
            sort: true,
            newLine: true
        )
        .set { ch_collated_versions }

    ch_published_sex_map = ch_effective_sex_map.map { _meta, sex_map_file ->
        sex_map_file
    }

    ch_published_preprocessed = ch_preprocessed.map { _meta, preprocessed_file ->
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
