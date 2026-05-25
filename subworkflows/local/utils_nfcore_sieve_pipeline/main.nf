//
// Subworkflow with functionality specific to the lescailab/sieve pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { UTILS_NFCORE_PIPELINE } from '../../nf-core/utils_nfcore_pipeline'
include { completionEmail; completionSummary } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE } from '../../nf-core/utils_nextflow_pipeline'
include { imNotification; validateSieveArguments } from '../../../lib/sieve_helpers'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    _monochrome_logs  // boolean: Do not use coloured log outputs
    nextflow_cli_args // array: List of positional nextflow CLI args
    outdir            // string: Path to output directory
    vcf               // string: Path to bgzipped indexed VCF
    phenotypes        // string: Path to phenotype TSV
    genome_build      // string: GRCh37 or GRCh38
    infer_sex         // boolean: whether to infer sex when sex_map not provided
    known_sex         // string: Optional known sex TSV used for sex-inference concordance checks
    sex_map           // string: Optional precomputed sex map TSV
    preprocessed_data // string: Optional preprocessed dataset (.pt)
    best_params       // string: Optional best-parameter YAML to skip grid search
    best_checkpoint   // string: Optional model checkpoint (.pt) to skip CV
    checkpoint_config // string: Optional config YAML paired with --best_checkpoint
    execute_step      // string: Optional comma-separated list of steps to execute
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    before_text = """
-
\033[2m----------------------------------------------------\033[0m-
                                        \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                        \033[0;32m`._,._,\'\033[0m
\033[0;35m  lescailab/sieve ${workflow.manifest.version}\033[0m
-
\033[2m----------------------------------------------------\033[0m-
"""

    after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/','')}"}.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/lescailab/sieve-nextflow/blob/master/CITATIONS.md
"""

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --vcf cohort.vcf.gz --phenotypes phenotypes.tsv --genome_build GRCh38 --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN(
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command
    )

    validateSieveArguments(
        vcf,
        phenotypes,
        genome_build,
        infer_sex,
        known_sex,
        sex_map,
        preprocessed_data,
        best_params,
        best_checkpoint,
        checkpoint_config,
        execute_step,
        params.cv_folds,
        params,
        log,
        { message -> error(message) }
    )

    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    emit:
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           // string: email address
    email_on_fail   // string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          // path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        // string: hook URL for notifications

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: 'nextflow_schema.json')

    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                []
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error 'Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting'
    }
}
