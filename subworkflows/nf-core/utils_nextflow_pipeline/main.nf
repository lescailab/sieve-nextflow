//
// Subworkflow with functionality that may be useful for any Nextflow pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW DEFINITION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UTILS_NEXTFLOW_PIPELINE {
    take:
    print_version        // boolean: print version
    dump_parameters      // boolean: dump parameters
    outdir               //    path: base directory used to publish pipeline results
    check_conda_channels // boolean: check conda channels

    main:

    //
    // Print workflow version and exit on --version
    //
    if (print_version) {
        log.info("${workflow.manifest.name} ${NfcoreTemplateUtils.getWorkflowVersion(workflow)}")
        System.exit(0)
    }

    //
    // Dump pipeline parameters to a JSON file
    //
    if (dump_parameters && outdir) {
        NextflowTemplateUtils.dumpParametersToJSON(outdir, workflow, params)
    }

    //
    // When running with Conda, warn if channels have not been set-up appropriately
    //
    if (check_conda_channels) {
        NextflowTemplateUtils.checkCondaChannels(log)
    }

    emit:
    dummy_emit = true
}
