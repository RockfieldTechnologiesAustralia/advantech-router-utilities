#!/bin/bash

set -e

BASE_PATH=$(cd $(readlink -f $0 | xargs dirname); pwd)
TMP_DIR=${BASE_PATH}/tmp
PYTHON_VERSION=$1
ADVANTECH_PACKAGE_VERSION=$2

if [ ! -d ${TMP_DIR} ]
then
  mkdir ${TMP_DIR}
fi

if [ -z "${PYTHON_VERSION}" ]
then
  echo "Python version not specified. Listing:"
  echo ""
  uv python list --all-platforms | grep armv7 | grep -v gnueabihf
  exit 0
fi

if [ -z "${ADVANTECH_PACKAGE_VERSION}" ]
then
  ADVANTECH_PACKAGE_VERSION=v3
fi

if [ ! -d ${TMP_DIR}/${PYTHON_VERSION} ]
then
  uv python install -i ${TMP_DIR} ${PYTHON_VERSION}
fi

INTERPRETER_VERSION=$(cat ${TMP_DIR}/${PYTHON_VERSION}/lib/python3*/_sysconfig_vars__linux_arm-linux-gnueabi.json | jq -r '.VERSION')

echo $INTERPRETER_VERSION
OUTPUT_PATH="${BASE_PATH}/../python-builds/python3-${INTERPRETER_VERSION}.${ADVANTECH_PACKAGE_VERSION}.tgz"

echo ${OUTPUT_PATH}

if [ ! -f ${OUTPUT_PATH} ]
then
  echo "Renaming directory"
  mv ${TMP_DIR}/${PYTHON_VERSION} ${TMP_DIR}/python3
  pushd ${TMP_DIR}
  tar -czavf ${OUTPUT_PATH} python3
  rm -Rf python3
  popd
fi