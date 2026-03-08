# GPU Local Disk Configuration

## Overview

The `conf/gpu_local_disk.config` configuration disables Fusion virtual filesystem for GPU processes and stages all files to local disk instead. This reduces memory pressure and improves I/O performance for GPU workloads.

## When to Use

Use this configuration when:
- Experiencing OOM (Out of Memory) errors on GPU nodes
- GPU processes are killed unexpectedly
- Heavy I/O operations are competing with GPU memory
- You need more predictable memory usage

## Changes Made

1. **Disables Fusion**: All file I/O happens through local disk instead of Fusion's virtual filesystem
2. **500GB Boot Disk**: GPU VMs get large boot disks to accommodate data staging
3. **Local Staging**: Files are copied to/from local disk (`stageInMode = 'copy'`, `stageOutMode = 'copy'`)
4. **Disables Cloud Cache**: Not compatible with local staging mode

## Usage

Include this config **after** your main Google Batch config:

```bash
nextflow run . \
  -c conf/google_batch_gpu32_no_spot.config \
  -c conf/gpu_local_disk.config \
  --vcf input.vcf \
  --phenotypes pheno.tsv \
  ...
```

Or on Seqera Platform, add it to your pipeline's "Nextflow config file" field:

```
includeConfig 'conf/google_batch_gpu32_no_spot.config'
includeConfig 'conf/gpu_local_disk.config'
```

## Trade-offs

### Benefits ✅
- Reduced memory pressure (no Fusion caching in RAM)
- Better I/O performance for large files
- More predictable resource usage
- Eliminates Fusion-related OOM issues

### Costs ⚠️
- Higher network egress costs (files copied to/from GCS)
- Longer stage-in/stage-out times for large files
- Increased boot disk costs (500GB vs default 10GB)

## Performance Impact

For the SIEVE explain process with:
- 3.9GB preprocessed data
- 1.5GB model checkpoint

**With Fusion**: Files accessed via virtual filesystem, but can cause OOM if buffer caching uses too much RAM

**With Local Disk**: 
- Stage-in: ~2-3 minutes to copy 5.4GB to local disk
- Computation: Runs with full available RAM (no Fusion overhead)
- Stage-out: ~1-2 minutes to copy results back

Net effect: Slightly longer total time, but **much more reliable** and no OOM failures.

## Monitoring

Check if local staging is working:

```bash
# In task work directory on VM
ls -lh /tmp/nxf*/work/*/  # Should see actual copied files, not tiny symlinks
df -h                     # Should show 500GB boot disk
```

## Troubleshooting

If jobs still fail:
1. Check actual memory usage in task logs (look for `peak_rss` in trace file)
2. Verify disk size: `df -h` should show ~500GB
3. Ensure Fusion is disabled: `echo $FUSION_ENABLED` should be "false"
4. Check if files are being copied: file sizes should match GCS originals, not be tiny symlinks
