//
// Subworkflow: Epistasis analysis — audit co-occurrence, validate epistasis, power analysis, gene interactions
//

include { SIEVE_AUDIT_COOCCURRENCE          } from '../../../modules/local/sieve/audit_cooccurrence/main'
include { SIEVE_VALIDATE_EPISTASIS          } from '../../../modules/local/sieve/validate_epistasis/main'
include { SIEVE_EPISTASIS_POWER_ANALYSIS    } from '../../../modules/local/sieve/epistasis_power_analysis/main'
include { SIEVE_AGGREGATE_GENE_INTERACTIONS } from '../../../modules/local/sieve/aggregate_gene_interactions/main'

workflow EPISTASIS {

    take:
    ch_preprocessed            // channel: [ val(meta), path(preprocessed) ]
    ch_preprocessed_keyed      // channel: [ val(cohort_id), path(preprocessed) ]
    ch_real_rankings           // channel: [ val(meta), path(variant), path(gene), path(interactions) ]
    ch_best_checkpoint_keyed   // channel: [ val(cohort_id), path(checkpoint), path(config) ]
    ch_null_attributions_npz   // channel: path(npz) or val([])
    ch_null_variant_rankings   // channel: path(rankings) or val([])

    main:

    ch_versions = channel.empty()
    ch_plot_sources = channel.empty()
    ch_published_explainability_analysis = channel.empty()

    //
    // Audit co-occurrence structure (runs in parallel with explain steps)
    //
    ch_audit_input = ch_preprocessed.map { meta, preprocessed ->
        tuple([id: meta.id, run_id: 'audit_cooccurrence', stage: 'epistasis'], preprocessed)
    }

    SIEVE_AUDIT_COOCCURRENCE(ch_audit_input)
    ch_versions = ch_versions.mix(SIEVE_AUDIT_COOCCURRENCE.out.versions)
    ch_plot_sources = ch_plot_sources.mix(SIEVE_AUDIT_COOCCURRENCE.out.cooccurrence_dir.map { _meta, cooccurrence_dir -> cooccurrence_dir })

    //
    // Validate epistasis (needs non-empty interactions from explain)
    //
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

    //
    // Epistasis power analysis (needs audit outputs + optional null attributions + optional epistasis results)
    //
    ch_cooccurrence_keyed = SIEVE_AUDIT_COOCCURRENCE.out.cooccurrence_pairs
        .join(SIEVE_AUDIT_COOCCURRENCE.out.cooccurrence_summary, by: 0)
        .map { meta, pairs, summary ->
            tuple(meta.id, pairs, summary)
        }

    // Optional: epistasis validation CSV (if validate_epistasis produced results)
    ch_epistasis_csv = SIEVE_VALIDATE_EPISTASIS.out.epistasis
        .map { _meta, epistasis_csv, _dir -> epistasis_csv }
        .ifEmpty([])

    ch_power_input = ch_cooccurrence_keyed
        .map { _key, pairs, summary ->
            tuple([id: _key, run_id: 'epistasis_power', stage: 'epistasis'], pairs, summary)
        }

    SIEVE_EPISTASIS_POWER_ANALYSIS(
        ch_power_input,
        ch_null_attributions_npz,
        ch_epistasis_csv
    )
    ch_versions = ch_versions.mix(SIEVE_EPISTASIS_POWER_ANALYSIS.out.versions)
    ch_plot_sources = ch_plot_sources.mix(SIEVE_EPISTASIS_POWER_ANALYSIS.out.power_analysis.map { _meta, power_dir, _summary -> power_dir })

    ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
        SIEVE_EPISTASIS_POWER_ANALYSIS.out.power_analysis.map { _meta, power_dir, power_summary ->
            [power_summary, power_dir]
        }
    )

    //
    // Aggregate gene-level interactions (needs rankings + preprocessed + optional null rankings + optional cooccurrence)
    //
    ch_gene_interactions_input = ch_real_rankings
        .map { meta, variant_rankings, gene_rankings, _interactions ->
            tuple(meta.id, variant_rankings, gene_rankings)
        }
        .join(ch_preprocessed_keyed, by: 0)
        .map { key, variant_rankings, gene_rankings, preprocessed ->
            tuple([id: key, run_id: 'gene_interactions', stage: 'epistasis'], preprocessed, variant_rankings, gene_rankings)
        }

    // Optional: cooccurrence per-pair CSV from audit
    ch_cooccur_pairs_for_agg = SIEVE_AUDIT_COOCCURRENCE.out.cooccurrence_pairs
        .map { _meta, pairs -> pairs }

    SIEVE_AGGREGATE_GENE_INTERACTIONS(
        ch_gene_interactions_input,
        ch_null_variant_rankings,
        ch_cooccur_pairs_for_agg
    )
    ch_versions = ch_versions.mix(SIEVE_AGGREGATE_GENE_INTERACTIONS.out.versions)
    ch_plot_sources = ch_plot_sources.mix(SIEVE_AGGREGATE_GENE_INTERACTIONS.out.gene_interactions.map { _meta, interactions_dir, _csv -> interactions_dir })

    ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
        SIEVE_AGGREGATE_GENE_INTERACTIONS.out.gene_interactions.map { _meta, interactions_dir, interactions_csv ->
            [interactions_csv, interactions_dir]
        }
    )
    ch_published_explainability_analysis = ch_published_explainability_analysis.mix(
        SIEVE_AGGREGATE_GENE_INTERACTIONS.out.network.map { _meta, edges, nodes ->
            [edges, nodes]
        }
    )

    emit:
    published_explainability_analysis = ch_published_explainability_analysis  // channel: publish files
    versions                          = ch_versions                           // channel: path(versions.yml)
    plot_sources                      = ch_plot_sources                        // channel: path(plot_files)
}
