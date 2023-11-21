#!/bin/sh
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

cd ../charts
set -x
helm package vdl
