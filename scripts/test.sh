#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
MODULE_CACHE="${PROJECT_ROOT}/.build/self-test-module-cache"
TEST_BINARY="${PROJECT_ROOT}/.build/MailSentinelSelfTest"

mkdir -p "${MODULE_CACHE}"

swiftc \
    -module-cache-path "${MODULE_CACHE}" \
    "${PROJECT_ROOT}/Sources/MailSentinel/Models.swift" \
    "${PROJECT_ROOT}/Sources/MailSentinel/Persistence.swift" \
    "${PROJECT_ROOT}/Sources/MailSentinel/MailReader.swift" \
    "${PROJECT_ROOT}/Tests/SelfTest/main.swift" \
    -o "${TEST_BINARY}"

"${TEST_BINARY}"
