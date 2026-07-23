# Google Batch A100 without Fusion

The bundled `google_batch_a100_no_fusion` profile runs GPU-labelled processes on Google Batch with an NVIDIA A100 accelerator and standard Cloud Storage staging. Fusion remains disabled.

## Configuration

The profile is defined in `conf/google_batch_a100_no_fusion.config` and sets:

| Setting | Value |
| --- | --- |
| Executor | `google-batch` |
| Machine type | `a2-highgpu-1g` |
| Accelerator | One `nvidia-tesla-a100` |
| Initial CPUs | 12 |
| Initial host memory | 85 GB |
| Initial time limit | 72 hours |
| Google Cloud region | `us-central1` |
| Spot instances | Enabled |

CPU, memory and time requests scale with each retry attempt. The profile applies these resources only to processes carrying the `process_gpu` label.

## Run the profile

From a local checkout, combine the Google Batch profile with the Docker and GPU profiles:

```bash
nextflow run . \
  -profile google_batch_a100_no_fusion,docker,gpu \
  --vcf /path/to/data.vcf.gz \
  --phenotypes /path/to/phenotypes.tsv \
  --genome_build GRCh38 \
  --outdir results
```

Your execution environment must supply the Google Cloud project, credentials and Cloud Storage work directory required by Nextflow. Keep those environment-specific values in a local config or your execution platform rather than in the repository.

## Staging behaviour

The profile does not enable Fusion or configure Fusion cache settings. Nextflow therefore stages files through standard Cloud Storage transfer for this profile. Use the execution trace and Google Batch task details to inspect transfer time, resource use and retry attempts.
