# A directory where the executable will be built
ARG KUBESCAPE_BUILD_DIR="/home/builder/kubescape-http"
# A directory where the Kubescape artifacts will be temporarily stored
ARG KUBESCAPE_ARTIFACTS_TMP_DIR="/tmp/kubescape-artifacts"
ARG KUBESCAPE_USER="kubescape"
ARG KUBESCAPE_GROUP="kubescape"

# Artifacts Stage: Download Kubescape artifacts for the HTTP server to use
FROM quay.io/kubescape/kubescape:v2.0.171 as artifacts-stage

# ARGs must be refreshed during each build stage
ARG KUBESCAPE_BUILD_DIR
ARG KUBESCAPE_ARTIFACTS_TMP_DIR
ARG KUBESCAPE_USER
ARG KUBESCAPE_GROUP

RUN kubescape download artifacts -o ${KUBESCAPE_ARTIFACTS_TMP_DIR}


# Executable build stage
FROM golang:1.18-alpine as build-stage

ARG KUBESCAPE_BUILD_DIR
ARG KUBESCAPE_ARTIFACTS_TMP_DIR
ARG KUBESCAPE_USER
ARG KUBESCAPE_GROUP

ARG image_version
ARG client

ENV RELEASE="$image_version"
ENV CLIENT="$client"

ENV GO111MODULE="" CGO_ENABLED="1"

# Install required python/pip
ENV PYTHONUNBUFFERED="1"
RUN apk add --update --no-cache python3 git openssl-dev musl-dev gcc make cmake pkgconfig && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools

WORKDIR ${KUBESCAPE_BUILD_DIR}
COPY . .

# install libgit2
RUN make libgit2

# build the Kubescape HTTP server
RUN python build.py


# Image Build Stage: build the deliverable image
FROM alpine:3.16.2

ARG KUBESCAPE_BUILD_DIR
ARG KUBESCAPE_ARTIFACTS_TMP_DIR
ARG KUBESCAPE_USER
ARG KUBESCAPE_GROUP

RUN addgroup -S ${KUBESCAPE_GROUP} && adduser -S ${KUBESCAPE_USER} -G ${KUBESCAPE_GROUP}

COPY --chown=${KUBESCAPE_USER}:${KUBESCAPE_GROUP} --from=artifacts-stage ${KUBESCAPE_ARTIFACTS_TMP_DIR} /home/${KUBESCAPE_USER}/.kubescape

USER ${KUBESCAPE_USER}

WORKDIR /home/${KUBESCAPE_USER}

COPY --chown=${KUBESCAPE_USER}:${KUBESCAPE_GROUP} --from=build-stage ${KUBESCAPE_BUILD_DIR}/build/ubuntu-latest/kubescape /usr/bin/kubescape-http

ENTRYPOINT ["kubescape-http"]
