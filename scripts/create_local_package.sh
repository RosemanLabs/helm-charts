#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

cd ../charts
set -x
helm package --dependency-update vdl
