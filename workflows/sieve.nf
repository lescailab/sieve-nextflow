/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

include { SIEVE_INFER_SEX } from '../modules/local/sieve/infer_sex/main'
include { SIEVE_EMIT_SEX_MAP } from '../modules/local/sieve/emit_sex_map/main'
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

    ch_vcf = Channel
        .fromPath(params.vcf, checkIfExists: true)
        .map { vcf -> tuple(cohortMeta, vcf) }

    ch_phenotypes = Channel
        .fromPath(params.phenotypes, checkIfExists: true)
        .map { phenotypes -> tuple(cohortMeta, phenotypes) }

    ch_sex_map = Channel.empty()

    if (params.sex_map) {
        ch_sex_map = Channel
            .fromPath(params.sex_map, checkIfExists: true)
            .map { sex_map -> tuple(cohortMeta, sex_map) }
    } else if (params.infer_sex) {
        SIEVE_INFER_SEX(
            ch_vcf,
            params.genome_build
        )
        ch_sex_map = SIEVE_INFER_SEX.out.sex_map
        ch_versions = ch_versions.mix(SIEVE_INFER_SEX.out.versions)
        ch_plot_sources = ch_plot_sources.mix(SIEVE_INFER_SEX.out.diagnostics.map { meta, diagnostic -> diagnostic })
    } else {
        error("Either --sex_map must be provided or --infer_sex must be true.")
    }

    SIEVE_EMIT_SEX_MAP(ch_sex_map)
    ch_versions = ch_versions.mix(SIEVE_EMIT_SEX_MAP.out.versions)

    ch_effective_sex_map = SIEVE_EMIT_SEX_MAP.out.sex_map

    ch_preprocess_input = ch_vcf
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

    ch_preprocessed_keyed = SIEVE_PREPROCESS.out.preprocessed.map { meta, preprocessed ->
        tuple(meta.id, preprocessed)
    }
    ch_sex_map_keyed = ch_effective_sex_map.map { meta, sex_map ->
        tuple(meta.id, sex_map)
    }

    def trainingGrid = buildTrainingGrid(
        params.grid_lr,
        params.grid_lambda_attr,
        params.grid_batch_size,
        params.grid_chunk_size,
        params.grid_aggregation_method
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

    ch_selection_meta = Channel.value([id: cohortMeta.id])

    SIEVE_SELECT_BEST_PARAMS(
        ch_selection_meta,
        ch_grid_selection_dirs
    )
    ch_versions = ch_versions.mix(SIEVE_SELECT_BEST_PARAMS.out.versions)

    ch_best_params_keyed = SIEVE_SELECT_BEST_PARAMS.out.best_params.map { meta, best_params, best_run_id, summary ->
        tuple(meta.id, best_params, best_run_id, summary)
    }

    ch_best_params_path_keyed = ch_best_params_keyed.map { cohort_id, best_params, best_run_id, summary ->
        tuple(cohort_id, best_params)
    }

    ch_best_params_map_keyed = ch_best_params_keyed.map { cohort_id, best_params, best_run_id, summary ->
        def yaml = new org.yaml.snakeyaml.Yaml()
        def parsed = yaml.load(best_params.text)
        parsed = parsed instanceof Map ? parsed : [:]
        tuple(cohort_id, parsed)
    }

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

    ch_explain_real_input = ch_best_checkpoint_keyed
        .join(ch_preprocessed_keyed, by: 0)
        .map { key, checkpoint, config, preprocessed ->
            tuple([id: key, run_id: 'explain_real', stage: 'explain', level: params.default_train_level], checkpoint, config, preprocessed, false)
        }

    SIEVE_EXPLAIN_REAL(ch_explain_real_input)
    ch_versions = ch_versions.mix(SIEVE_EXPLAIN_REAL.out.versions)
    ch_plot_sources = ch_plot_sources.mix(SIEVE_EXPLAIN_REAL.out.explain_dir.map { meta, explain_dir -> explain_dir })

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
            def ablationParams = new LinkedHashMap(best_params_map)
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
            def nullParams = new LinkedHashMap(best_params_map)
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

    ch_real_variant_keyed = SIEVE_EXPLAIN_REAL.out.rankings.map { meta, variant_rankings, gene_rankings, interactions ->
        tuple(meta.id, variant_rankings)
    }

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

    ch_nonempty_interactions_keyed = SIEVE_EXPLAIN_REAL.out.rankings
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

    ch_discovery_validation_input = SIEVE_EXPLAIN_REAL.out.rankings.map { meta, variant_rankings, gene_rankings, interactions ->
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

    ch_plot_sources_list = ch_plot_sources.collect()

    SIEVE_COLLECT_PLOTS(
        ch_selection_meta,
        ch_plot_sources_list
    )
    ch_versions = ch_versions.mix(SIEVE_COLLECT_PLOTS.out.versions)

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
    ch_published_preprocessed = SIEVE_PREPROCESS.out.preprocessed.map { meta, preprocessed_file ->
        preprocessed_file
    }
    ch_published_best_model = SIEVE_SELECT_BEST_CHECKPOINT.out.best_checkpoint.map { meta, checkpoint, fold_config, fold_id, cv_summary ->
        [checkpoint, fold_config, fold_id, cv_summary]
    }
    ch_published_explainability_best = SIEVE_EXPLAIN_REAL.out.explain_dir.map { meta, explain_dir ->
        explain_dir
    }
    ch_published_explainability_analysis = SIEVE_VALIDATE_DISCOVERIES.out.validation
        .map { meta, validation_report, validation_dir ->
            [validation_report, validation_dir]
        }
        .mix(
            SIEVE_VALIDATE_EPISTASIS.out.epistasis.map { meta, epistasis_validation, epistasis_dir ->
                [epistasis_validation, epistasis_dir]
            }
        )
    ch_published_ablation_discovery = SIEVE_ABLATION_COMPARE.out.ablation_summary
        .map { meta, ablation_tsv, ablation_yaml ->
            [ablation_tsv, ablation_yaml]
        }
        .mix(
            SIEVE_TRAIN_SINGLE_ABLATION.out.selection_payload.map { meta, run_dir ->
                run_dir
            }
        )
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
    ch_published_plots = SIEVE_COLLECT_PLOTS.out.plot_bundle.map { meta, plots_dir, plots_manifest ->
        [plots_dir, plots_manifest]
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

def toList(value) {
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

def buildTrainingGrid(lrValues, lambdaAttrValues, batchSizeValues, chunkSizeValues, aggregationMethods) {
    def lrList = toList(lrValues).collect { it as Double }
    def lambdaList = toList(lambdaAttrValues).collect { it as Double }
    def batchList = toList(batchSizeValues).collect { it as Integer }
    def chunkList = toList(chunkSizeValues).collect { it as Integer }
    def aggList = toList(aggregationMethods)

    def grid = []
    int runCounter = 0

    lrList.each { lr ->
        lambdaList.each { lambda_attr ->
            batchList.each { batch_size ->
                chunkList.each { chunk_size ->
                    aggList.each { aggregation_method ->
                        runCounter += 1
                        grid << [
                            run_id: String.format('grid_%03d', runCounter),
                            lr: lr,
                            lambda_attr: lambda_attr,
                            batch_size: batch_size,
                            chunk_size: chunk_size,
                            aggregation_method: aggregation_method,
                        ]
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
