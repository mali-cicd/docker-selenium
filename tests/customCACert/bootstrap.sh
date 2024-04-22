#!/bin/bash
set -x

# Function to be executed on command failure
on_failure() {
    local exit_status=$?
    echo "There is step failed with exit status $exit_status"
    exit $exit_status
}

# Trap ERR signal and call on_failure function
trap 'on_failure' ERR

NAMESPACE=${NAME:-"selenium"}
VERSION=${VERSION:-$TAG_VERSION}
CERT_FILE=${CERT_FILE:-"./charts/selenium-grid/certs/*.pem"}
CERT_SCRIPT=${CERT_SCRIPT:-"./tests/customCACert/cert-script.sh"}

COMMON_BUILD_ARGS="--build-arg NAMESPACE=${NAMESPACE} --build-arg VERSION=${VERSION} --build-arg CERT_FILE=${CERT_FILE} --build-arg CERT_SCRIPT=${CERT_SCRIPT}"

docker build ${COMMON_BUILD_ARGS} --build-arg BASE=node-chrome -t ${NAMESPACE}/node-chrome:${VERSION} -f ./tests/customCACert/Dockerfile .
docker build ${COMMON_BUILD_ARGS} --build-arg BASE=node-firefox -t ${NAMESPACE}/node-firefox:${VERSION} -f ./tests/customCACert/Dockerfile .
docker build ${COMMON_BUILD_ARGS} --build-arg BASE=node-edge -t ${NAMESPACE}/node-edge:${VERSION} -f ./tests/customCACert/Dockerfile .

list_cert_files=($(find ./charts/selenium-grid/certs/ -name "*.pem"))
for cert_file_path in "${list_cert_files[@]}"; do
  cert_file_name="$(basename ${cert_file_path})"
  cert_name="${cert_file_name%.*}"
  docker run --entrypoint="" --rm  ${NAMESPACE}/node-chrome:${VERSION} bash -c "certutil -L -d sql:/home/seluser/.pki/nssdb -n ${cert_name}" | grep -q "SeleniumHQ"
  docker run --entrypoint="" --rm  ${NAMESPACE}/node-firefox:${VERSION} bash -c "certutil -L -d sql:/home/seluser/.pki/nssdb -n ${cert_name}" | grep -q "SeleniumHQ"
  docker run --entrypoint="" --rm  ${NAMESPACE}/node-edge:${VERSION} bash -c "certutil -L -d sql:/home/seluser/.pki/nssdb -n ${cert_name}" | grep -q "SeleniumHQ"
done
