#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-2

set -exo pipefail

DOCKER_SCRIPT="docker.run"
COV_SCRIPT="coverity.run"

#export PROJECT="tpm2-totp"
export PROJECT=$PROJECT_NAME
export DOCKER_BUILD_DIR="/workspace/$PROJECT"

# if no DOCKER_IMAGE is set, warn and default to fedora-30
if [ -z "$DOCKER_IMAGE" ]; then
  echo "WARN: DOCKER_IMAGE is not set, defaulting to fedora-32"
  export DOCKER_IMAGE="fedora-32"
fi

#
# Docker starts you in a cloned repo of your project with the PR checkout out.
# We want those changes IN the docker image, so use the -v option to mount the
# project repo in the docker image.
#
# Also, pass in any env variables required for the build via .ci/docker.env file
#
# Execute the build and test procedure by running .ci/docker.run
#

ci_env=""
if [ "$ENABLE_COVERAGE" == "true" ]; then
  ci_env=$(bash <(curl -s https://codecov.io/env))
fi


if [ "$ENABLE_COVERITY" == "true" ]; then
  echo "Running coverity build"
  script="$COV_SCRIPT"
else
  echo "Running non-coverity build"
  script="$DOCKER_SCRIPT"
fi

# Register binfmt_misc entry for qemu-user-static
case ${DOCKER_ARCH} in
  amd64|i386)
    QEMU_ARCH=
    ;;
  arm32*)
    QEMU_ARCH=arm
    ;;
  arm64*)
    QEMU_ARCH=aarch64
    ;;
  *)
    QEMU_ARCH=${DOCKER_ARCH}
    ;;
esac
if [ -n "${QEMU_ARCH}" ]; then
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi

docker run --cap-add=SYS_PTRACE $ci_env --env-file .ci/docker.env \
  -v "$(pwd):$DOCKER_BUILD_DIR" "ghcr.io/joholl/$DOCKER_IMAGE" \
  /bin/bash -c "$DOCKER_BUILD_DIR/.ci/$script"

exit 0
