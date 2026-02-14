class NextflowTemplateUtils {

    static void dumpParametersToJSON(outdir, workflow, params) {
        def timestamp = new java.util.Date().format('yyyy-MM-dd_HH-mm-ss')
        def filename = "params_${timestamp}.json"
        def tempParamFile = new File(workflow.launchDir.toString(), ".${filename}")
        def jsonStr = groovy.json.JsonOutput.toJson(params)
        tempParamFile.text = groovy.json.JsonOutput.prettyPrint(jsonStr)

        nextflow.extension.FilesEx.copyTo(tempParamFile.toPath(), "${outdir}/pipeline_info/params_${timestamp}.json")
        tempParamFile.delete()
    }

    static void checkCondaChannels(log) {
        def parser = new org.yaml.snakeyaml.Yaml()
        def channels = []
        try {
            def config = parser.load('conda config --show channels'.execute().text)
            channels = config.channels
        } catch (NullPointerException e) {
            log.debug(e)
            log.warn('Could not verify conda channel configuration.')
            return
        } catch (IOException e) {
            log.debug(e)
            log.warn('Could not verify conda channel configuration.')
            return
        }

        def requiredChannelsInOrder = ['conda-forge', 'bioconda']
        def channelsMissing = ((requiredChannelsInOrder as Set) - (channels as Set)) as Boolean
        def channelPriorityViolation = requiredChannelsInOrder != channels.findAll { ch -> ch in requiredChannelsInOrder }

        if (channelsMissing | channelPriorityViolation) {
            log.warn("""\
            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                There is a problem with your Conda configuration!
                You will need to set-up the conda-forge and bioconda channels correctly.
                Please refer to https://bioconda.github.io/
                The observed channel order is
                ${channels}
                but the following channel order is required:
                ${requiredChannelsInOrder}
            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
            """.stripIndent(true))
        }
    }
}
