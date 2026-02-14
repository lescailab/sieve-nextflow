class NfcoreTemplateUtils {

    static boolean checkConfigProvided(workflow, log) {
        boolean validConfig = true
        if (workflow.profile == 'standard' && workflow.configFiles.size() <= 1) {
            log.warn(
                "[${workflow.manifest.name}] You are attempting to run the pipeline without any custom configuration!\n\n" +
                "This will be dependent on your local compute environment but can be achieved via one or more of the following:\n" +
                "   (1) Using an existing pipeline profile e.g. `-profile docker` or `-profile singularity`\n" +
                "   (2) Using an existing nf-core/configs for your Institution e.g. `-profile crick` or `-profile uppmax`\n" +
                "   (3) Using your own local custom config e.g. `-c /path/to/your/custom.config`\n\n" +
                "Please refer to the quick start section and usage docs for the pipeline.\n "
            )
            validConfig = false
        }
        return validConfig
    }

    static void checkProfileProvided(workflow, nextflowCliArgs, log, Closure errorFn) {
        final Closure fail = errorFn ?: { String message -> throw new IllegalArgumentException(message) }
        if (workflow.profile.endsWith(',')) {
            fail.call(
                "The `-profile` option cannot end with a trailing comma, please remove it and re-run the pipeline!\n" +
                "HINT: A common mistake is to provide multiple values separated by spaces e.g. `-profile test, docker`.\n"
            )
        }
        if (nextflowCliArgs && nextflowCliArgs[0]) {
            log.warn(
                "nf-core pipelines do not accept positional arguments. The positional argument `${nextflowCliArgs[0]}` has been detected.\n" +
                "HINT: A common mistake is to provide multiple values separated by spaces e.g. `-profile test, docker`.\n"
            )
        }
    }

    static String getWorkflowVersion(workflow) {
        String versionString = ''
        if (workflow.manifest.version) {
            def prefixV = workflow.manifest.version[0] != 'v' ? 'v' : ''
            versionString += "${prefixV}${workflow.manifest.version}"
        }

        if (workflow.commitId) {
            def gitShortsha = workflow.commitId.substring(0, 7)
            versionString += "-g${gitShortsha}"
        }

        return versionString
    }

    static String processVersionsFromYAML(yamlFile) {
        def yaml = new org.yaml.snakeyaml.Yaml()
        def versions = yaml.load(yamlFile).collectEntries { k, v -> [k.tokenize(':')[-1], v] }
        return yaml.dumpAsMap(versions).trim()
    }

    static String workflowVersionToYAML(workflow) {
        return """
        Workflow:
            ${workflow.manifest.name}: ${getWorkflowVersion(workflow)}
            Nextflow: ${workflow.nextflow.version}
        """.stripIndent().trim()
    }

    static softwareVersionsToYAML(chVersions, workflow) {
        return chVersions
            .unique()
            .map { version -> processVersionsFromYAML(version) }
            .unique()
            .mix(nextflow.Channel.of(workflowVersionToYAML(workflow)))
    }

    static String paramsSummaryMultiqc(summaryParams, workflow) {
        String summarySection = ''
        summaryParams
            .keySet()
            .each { group ->
                def groupParams = summaryParams.get(group)
                if (groupParams) {
                    summarySection += "    <p style=\"font-size:110%\"><b>${group}</b></p>\n"
                    summarySection += "    <dl class=\"dl-horizontal\">\n"
                    groupParams
                        .keySet()
                        .sort()
                        .each { param ->
                            summarySection += "        <dt>${param}</dt><dd><samp>${groupParams.get(param) ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>\n"
                        }
                    summarySection += "    </dl>\n"
                }
            }

        String yamlFileText = "id: '${workflow.manifest.name.replace('/', '-')}-summary'\n"
        yamlFileText += "description: ' - this information is collected when the pipeline is started.'\n"
        yamlFileText += "section_name: '${workflow.manifest.name} Workflow Summary'\n"
        yamlFileText += "section_href: 'https://github.com/${workflow.manifest.name}'\n"
        yamlFileText += "plot_type: 'html'\n"
        yamlFileText += "data: |\n"
        yamlFileText += "${summarySection}"

        return yamlFileText
    }

    static Map logColours(boolean monochromeLogs = true) {
        def colorcodes = [:] as Map

        colorcodes['reset'] = monochromeLogs ? '' : "\033[0m"
        colorcodes['bold'] = monochromeLogs ? '' : "\033[1m"
        colorcodes['dim'] = monochromeLogs ? '' : "\033[2m"
        colorcodes['underlined'] = monochromeLogs ? '' : "\033[4m"
        colorcodes['blink'] = monochromeLogs ? '' : "\033[5m"
        colorcodes['reverse'] = monochromeLogs ? '' : "\033[7m"
        colorcodes['hidden'] = monochromeLogs ? '' : "\033[8m"

        colorcodes['black'] = monochromeLogs ? '' : "\033[0;30m"
        colorcodes['red'] = monochromeLogs ? '' : "\033[0;31m"
        colorcodes['green'] = monochromeLogs ? '' : "\033[0;32m"
        colorcodes['yellow'] = monochromeLogs ? '' : "\033[0;33m"
        colorcodes['blue'] = monochromeLogs ? '' : "\033[0;34m"
        colorcodes['purple'] = monochromeLogs ? '' : "\033[0;35m"
        colorcodes['cyan'] = monochromeLogs ? '' : "\033[0;36m"
        colorcodes['white'] = monochromeLogs ? '' : "\033[0;37m"

        colorcodes['bblack'] = monochromeLogs ? '' : "\033[1;30m"
        colorcodes['bred'] = monochromeLogs ? '' : "\033[1;31m"
        colorcodes['bgreen'] = monochromeLogs ? '' : "\033[1;32m"
        colorcodes['byellow'] = monochromeLogs ? '' : "\033[1;33m"
        colorcodes['bblue'] = monochromeLogs ? '' : "\033[1;34m"
        colorcodes['bpurple'] = monochromeLogs ? '' : "\033[1;35m"
        colorcodes['bcyan'] = monochromeLogs ? '' : "\033[1;36m"
        colorcodes['bwhite'] = monochromeLogs ? '' : "\033[1;37m"

        colorcodes['ublack'] = monochromeLogs ? '' : "\033[4;30m"
        colorcodes['ured'] = monochromeLogs ? '' : "\033[4;31m"
        colorcodes['ugreen'] = monochromeLogs ? '' : "\033[4;32m"
        colorcodes['uyellow'] = monochromeLogs ? '' : "\033[4;33m"
        colorcodes['ublue'] = monochromeLogs ? '' : "\033[4;34m"
        colorcodes['upurple'] = monochromeLogs ? '' : "\033[4;35m"
        colorcodes['ucyan'] = monochromeLogs ? '' : "\033[4;36m"
        colorcodes['uwhite'] = monochromeLogs ? '' : "\033[4;37m"

        colorcodes['iblack'] = monochromeLogs ? '' : "\033[0;90m"
        colorcodes['ired'] = monochromeLogs ? '' : "\033[0;91m"
        colorcodes['igreen'] = monochromeLogs ? '' : "\033[0;92m"
        colorcodes['iyellow'] = monochromeLogs ? '' : "\033[0;93m"
        colorcodes['iblue'] = monochromeLogs ? '' : "\033[0;94m"
        colorcodes['ipurple'] = monochromeLogs ? '' : "\033[0;95m"
        colorcodes['icyan'] = monochromeLogs ? '' : "\033[0;96m"
        colorcodes['iwhite'] = monochromeLogs ? '' : "\033[0;97m"

        colorcodes['biblack'] = monochromeLogs ? '' : "\033[1;90m"
        colorcodes['bired'] = monochromeLogs ? '' : "\033[1;91m"
        colorcodes['bigreen'] = monochromeLogs ? '' : "\033[1;92m"
        colorcodes['biyellow'] = monochromeLogs ? '' : "\033[1;93m"
        colorcodes['biblue'] = monochromeLogs ? '' : "\033[1;94m"
        colorcodes['bipurple'] = monochromeLogs ? '' : "\033[1;95m"
        colorcodes['bicyan'] = monochromeLogs ? '' : "\033[1;96m"
        colorcodes['biwhite'] = monochromeLogs ? '' : "\033[1;97m"

        return colorcodes
    }

    static getSingleReport(multiqcReports, workflow, log) {
        if (multiqcReports instanceof java.nio.file.Path) {
            return multiqcReports
        }
        if (multiqcReports instanceof List) {
            if (multiqcReports.size() == 0) {
                log.warn("[${workflow.manifest.name}] No reports found from process 'MULTIQC'")
                return null
            }
            if (multiqcReports.size() == 1) {
                return multiqcReports.first()
            }
            log.warn("[${workflow.manifest.name}] Found multiple reports from process 'MULTIQC', will use only one")
            return multiqcReports.first()
        }
        return null
    }

    static void completionEmail(summaryParams, email, emailOnFail, plaintextEmail, outdir, boolean monochromeLogs, multiqcReport, workflow, params, log) {
        def subject = "[${workflow.manifest.name}] Successful: ${workflow.runName}"
        if (!workflow.success) {
            subject = "[${workflow.manifest.name}] FAILED: ${workflow.runName}"
        }

        def summary = [:]
        summaryParams
            .keySet()
            .sort()
            .each { group ->
                summary << summaryParams[group]
            }

        def miscFields = [:]
        miscFields['Date Started'] = workflow.start
        miscFields['Date Completed'] = workflow.complete
        miscFields['Pipeline script file path'] = workflow.scriptFile
        miscFields['Pipeline script hash ID'] = workflow.scriptId
        if (workflow.repository) {
            miscFields['Pipeline repository Git URL'] = workflow.repository
        }
        if (workflow.commitId) {
            miscFields['Pipeline repository Git Commit'] = workflow.commitId
        }
        if (workflow.revision) {
            miscFields['Pipeline Git branch/tag'] = workflow.revision
        }
        miscFields['Nextflow Version'] = workflow.nextflow.version
        miscFields['Nextflow Build'] = workflow.nextflow.build
        miscFields['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

        def emailFields = [:]
        emailFields['version'] = getWorkflowVersion(workflow)
        emailFields['runName'] = workflow.runName
        emailFields['success'] = workflow.success
        emailFields['dateComplete'] = workflow.complete
        emailFields['duration'] = workflow.duration
        emailFields['exitStatus'] = workflow.exitStatus
        emailFields['errorMessage'] = (workflow.errorMessage ?: 'None')
        emailFields['errorReport'] = (workflow.errorReport ?: 'None')
        emailFields['commandLine'] = workflow.commandLine
        emailFields['projectDir'] = workflow.projectDir
        emailFields['summary'] = summary << miscFields

        def mqcReport = getSingleReport(multiqcReport, workflow, log)

        def emailAddress = email
        if (!email && emailOnFail && !workflow.success) {
            emailAddress = emailOnFail
        }

        def engine = new groovy.text.GStringTemplateEngine()
        def txtTemplateFile = new File("${workflow.projectDir}/assets/email_template.txt")
        def txtTemplate = engine.createTemplate(txtTemplateFile).make(emailFields)
        def emailTxt = txtTemplate.toString()

        def htmlTemplateFile = new File("${workflow.projectDir}/assets/email_template.html")
        def htmlTemplate = engine.createTemplate(htmlTemplateFile).make(emailFields)
        def emailHtml = htmlTemplate.toString()

        def maxMultiqcEmailSize = (params.containsKey('max_multiqc_email_size') ? params.max_multiqc_email_size : 0) as nextflow.util.MemoryUnit
        def sendmailFields = [
            email: emailAddress,
            subject: subject,
            email_txt: emailTxt,
            email_html: emailHtml,
            projectDir: "${workflow.projectDir}",
            mqcFile: mqcReport,
            mqcMaxSize: maxMultiqcEmailSize.toBytes(),
        ]
        def sendmailTemplateFile = new File("${workflow.projectDir}/assets/sendmail_template.txt")
        def sendmailTemplate = engine.createTemplate(sendmailTemplateFile).make(sendmailFields)
        def sendmailHtml = sendmailTemplate.toString()

        def colors = logColours(monochromeLogs)
        if (emailAddress) {
            try {
                if (plaintextEmail) {
                    new org.codehaus.groovy.GroovyException('Send plaintext e-mail, not HTML')
                }
                def sendmailTmp = new File(workflow.launchDir.toString(), '.sendmail_tmp.html')
                sendmailTmp.withWriter { writer -> writer << sendmailHtml }
                ['sendmail', '-t'].execute() << sendmailHtml
                log.info("-${colors.purple}[${workflow.manifest.name}]${colors.green} Sent summary e-mail to ${emailAddress} (sendmail)-")
            } catch (Exception msg) {
                log.debug(msg.toString())
                log.debug('Trying with mail instead of sendmail')
                def mailCmd = ['mail', '-s', subject, '--content-type=text/html', emailAddress]
                mailCmd.execute() << emailHtml
                log.info("-${colors.purple}[${workflow.manifest.name}]${colors.green} Sent summary e-mail to ${emailAddress} (mail)-")
            }
        }

        def outputHtmlFile = new File(workflow.launchDir.toString(), '.pipeline_report.html')
        outputHtmlFile.withWriter { writer -> writer << emailHtml }
        nextflow.extension.FilesEx.copyTo(outputHtmlFile.toPath(), "${outdir}/pipeline_info/pipeline_report.html")
        outputHtmlFile.delete()

        def outputTxtFile = new File(workflow.launchDir.toString(), '.pipeline_report.txt')
        outputTxtFile.withWriter { writer -> writer << emailTxt }
        nextflow.extension.FilesEx.copyTo(outputTxtFile.toPath(), "${outdir}/pipeline_info/pipeline_report.txt")
        outputTxtFile.delete()
    }

    static void completionSummary(workflow, log, boolean monochromeLogs = true) {
        def colors = logColours(monochromeLogs)
        if (workflow.success) {
            if (workflow.stats.ignoredCount == 0) {
                log.info("-${colors.purple}[${workflow.manifest.name}]${colors.green} Pipeline completed successfully${colors.reset}-")
            } else {
                log.info("-${colors.purple}[${workflow.manifest.name}]${colors.yellow} Pipeline completed successfully, but with errored process(es) ${colors.reset}-")
            }
        } else {
            log.info("-${colors.purple}[${workflow.manifest.name}]${colors.red} Pipeline completed with errors${colors.reset}-")
        }
    }

    static void imNotification(summaryParams, hookUrl, workflow, log) {
        def summary = [:]
        summaryParams
            .keySet()
            .sort()
            .each { group ->
                summary << summaryParams[group]
            }

        def miscFields = [:]
        miscFields['start'] = workflow.start
        miscFields['complete'] = workflow.complete
        miscFields['scriptfile'] = workflow.scriptFile
        miscFields['scriptid'] = workflow.scriptId
        if (workflow.repository) {
            miscFields['repository'] = workflow.repository
        }
        if (workflow.commitId) {
            miscFields['commitid'] = workflow.commitId
        }
        if (workflow.revision) {
            miscFields['revision'] = workflow.revision
        }
        miscFields['nxf_version'] = workflow.nextflow.version
        miscFields['nxf_build'] = workflow.nextflow.build
        miscFields['nxf_timestamp'] = workflow.nextflow.timestamp

        def msgFields = [:]
        msgFields['version'] = getWorkflowVersion(workflow)
        msgFields['runName'] = workflow.runName
        msgFields['success'] = workflow.success
        msgFields['dateComplete'] = workflow.complete
        msgFields['duration'] = workflow.duration
        msgFields['exitStatus'] = workflow.exitStatus
        msgFields['errorMessage'] = (workflow.errorMessage ?: 'None')
        msgFields['errorReport'] = (workflow.errorReport ?: 'None')
        msgFields['commandLine'] = workflow.commandLine.replaceFirst(/ +--hook_url +[^ ]+/, '')
        msgFields['projectDir'] = workflow.projectDir
        msgFields['summary'] = summary << miscFields

        def engine = new groovy.text.GStringTemplateEngine()
        def jsonPath = hookUrl.contains('hooks.slack.com') ? 'slackreport.json' : 'adaptivecard.json'
        def jsonTemplateFile = new File("${workflow.projectDir}/assets/${jsonPath}")
        def jsonTemplate = engine.createTemplate(jsonTemplateFile).make(msgFields)
        def jsonMessage = jsonTemplate.toString()

        def post = new URL(hookUrl).openConnection()
        post.setRequestMethod('POST')
        post.setDoOutput(true)
        post.setRequestProperty('Content-Type', 'application/json')
        post.getOutputStream().write(jsonMessage.getBytes('UTF-8'))
        def postRC = post.getResponseCode()
        if (!postRC.equals(200)) {
            log.warn(post.getErrorStream().getText())
        }
    }
}
