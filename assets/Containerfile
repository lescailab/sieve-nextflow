FROM nvidia/cuda:12.6.3-runtime-ubuntu24.04

# Install micromamba
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates bzip2 \
    && curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj -C /usr bin/micromamba \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV MAMBA_ROOT_PREFIX=/opt/conda

# Tell conda that CUDA 12.6 is available on the system
ENV CONDA_OVERRIDE_CUDA=12.6

# Install conda environment
COPY environment.yml /tmp/environment.yml
RUN /usr/bin/micromamba install -y -n base -f /tmp/environment.yml \
    && /usr/bin/micromamba clean --all --yes

ENV PATH=/opt/conda/bin:$PATH
