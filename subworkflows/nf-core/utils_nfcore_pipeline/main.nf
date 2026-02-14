//
// Subworkflow with utility functions specific to the nf-core pipeline template
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW DEFINITION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UTILS_NFCORE_PIPELINE {
    take:
    nextflow_cli_args

    main:
    valid_config = NfcoreTemplateUtils.checkConfigProvided(workflow, log)
    NfcoreTemplateUtils.checkProfileProvided(workflow, nextflow_cli_args, log, { message -> error(message) })

    emit:
    valid_config
}
