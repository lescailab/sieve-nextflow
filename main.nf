#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    lescailab/sieve
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/lescailab/sieve-nextflow
    Website: https://nf-co.re/sieve
    Slack  : https://nfcore.slack.com/channels/sieve
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SIEVE } from './workflows/sieve'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_sieve_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_nfcore_sieve_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NFCORE_SIEVE {

    main:

    SIEVE()

    emit:
    sex_map                   = SIEVE.out.sex_map
    preprocessed_dataset      = SIEVE.out.preprocessed_dataset
    best_model                = SIEVE.out.best_model
    explainability_best_model = SIEVE.out.explainability_best_model
    explainability_analysis   = SIEVE.out.explainability_analysis
    ablation_discovery        = SIEVE.out.ablation_discovery
    null_model                = SIEVE.out.null_model
    null_comparison           = SIEVE.out.null_comparison
    null_comparison_sex_fixed = SIEVE.out.null_comparison_sex_fixed
    plots                     = SIEVE.out.plots
    pipeline_versions         = SIEVE.out.pipeline_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        [],
        params.outdir,
        params.vcf,
        params.phenotypes,
        params.genome_build,
        params.infer_sex,
        params.sex_map,
        params.preprocessed_data,
        params.best_params,
        params.best_checkpoint,
        params.checkpoint_config,
        params.execute_step,
        params.help,
        params.help_full,
        params.show_hidden
    )

    NFCORE_SIEVE()

    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
    )

    publish:
    sex_map                   = NFCORE_SIEVE.out.sex_map
    preprocessed_dataset      = NFCORE_SIEVE.out.preprocessed_dataset
    best_model                = NFCORE_SIEVE.out.best_model
    explainability_best_model = NFCORE_SIEVE.out.explainability_best_model
    explainability_analysis   = NFCORE_SIEVE.out.explainability_analysis
    ablation_discovery        = NFCORE_SIEVE.out.ablation_discovery
    null_model                = NFCORE_SIEVE.out.null_model
    null_comparison           = NFCORE_SIEVE.out.null_comparison
    null_comparison_sex_fixed = NFCORE_SIEVE.out.null_comparison_sex_fixed
    plots                     = NFCORE_SIEVE.out.plots
    pipeline_versions         = NFCORE_SIEVE.out.pipeline_versions
}

output {
    sex_map { path 'data/sex_map' }
    preprocessed_dataset { path 'data/preprocessed' }
    best_model { path 'models/best_model' }
    explainability_best_model { path 'explainability/best_model' }
    explainability_analysis { path 'explainability/analysis' }
    ablation_discovery { path 'ablation/discovery' }
    null_model { path 'null/model' }
    null_comparison { path 'null/comparison' }
    null_comparison_sex_fixed { path 'null/comparison_sex_chrom_fixed' }
    plots { path 'plots' }
    pipeline_versions { path 'pipeline_info' }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
