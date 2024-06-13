ARG py_version=3.11.2

FROM --platform=linux/amd64 python:$py_version-slim-bullseye as base

RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    ca-certificates=20210119 \
    git=1:2.30.2-1+deb11u2 \
    libpq-dev=13.14-0+deb11u1 \
    make=4.3-4.1 \
    openssh-client=1:8.4p1-5+deb11u3 \
    software-properties-common=0.96.20.2-2.1 \
  && apt-get clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

RUN python -m pip install --upgrade "pip==24.0" "setuptools==69.2.0" "wheel==0.43.0" --no-cache-dir


## DBT CORE
FROM base as dbt-core

# comit for DBT core v1.8 https://github.com/dbt-labs/dbt-core/releases/tag/v1.8.0
ARG commit_ref=v1.8.0

HEALTHCHECK CMD dbt --version || exit 1

WORKDIR /usr/app/dbt/

ENTRYPOINT ["dbt build"]

RUN python -m pip install --no-cache-dir "dbt-core @ git+https://github.com/dbt-labs/dbt-core@${commit_ref}#subdirectory=core"


## REDSHIFT
FROM dbt-core as dbt-redshift

# commit for Redshift v1.8 https://github.com/dbt-labs/dbt-redshift/releases/tag/v1.8.0
ARG commit_ref=v1.8.0

RUN python -m pip install --no-cache-dir "dbt-redshift @ git+https://github.com/dbt-labs/dbt-redshift@${commit_ref}#egg=dbt-redshift"