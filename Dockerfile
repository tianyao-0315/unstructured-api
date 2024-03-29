# syntax=docker/dockerfile:experimental
FROM quay.io/unstructured-io/base-images:rocky9.2-9@sha256:73d8492452f086144d4b92b7931aa04719f085c74d16cae81e8826ef873729c9 as base

ARG PIP_VERSION
ARG PIPELINE_PACKAGE

# Set up environment
ENV USER root
ENV HOME /root

RUN groupadd --gid 0 root
RUN useradd --uid 0 --gid 0 root
WORKDIR ${HOME}

ENV PYTHONPATH="${PYTHONPATH}:${HOME}"
ENV PATH="/root/.local/bin:${PATH}"

FROM base as python-deps
# COPY requirements/dev.txt requirements-dev.txt
COPY requirements/base.txt requirements-base.txt
RUN python3.10 -m pip install pip==${PIP_VERSION} \
  && dnf -y groupinstall "Development Tools" \
  && su -l root -c 'pip3.10 install  --no-cache  -r requirements-base.txt' \
  && dnf -y groupremove "Development Tools" \
  && dnf clean all \
  && ln -s /root/.local/bin/pip3.10 /usr/local/bin/pip3.10 || true

USER root

FROM python-deps as model-deps
RUN python3.10 -c "import nltk; nltk.download('punkt')" && \
  python3.10 -c "import nltk; nltk.download('averaged_perceptron_tagger')" && \
  python3.10 -c "from unstructured.partition.model_init import initialize; initialize()"

FROM model-deps as code
COPY --chown=root:root CHANGELOG.md CHANGELOG.md
COPY --chown=root:root logger_config.yaml logger_config.yaml
COPY --chown=root:root prepline_${PIPELINE_PACKAGE}/ prepline_${PIPELINE_PACKAGE}/
COPY --chown=root:root exploration-notebooks exploration-notebooks
COPY --chown=root:root scripts/app-start.sh scripts/app-start.sh

ENTRYPOINT ["scripts/app-start.sh"]
# Expose a default port of 8000. Note: The EXPOSE instruction does not actually publish the port,
# but some tooling will inspect containers and perform work contingent on networking support declared.
EXPOSE 8000