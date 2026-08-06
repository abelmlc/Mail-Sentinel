#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
APP_DIR="${PROJECT_ROOT}/dist/Mail Sentinel.app"
CONTENTS_DIR="${APP_DIR}/Contents"

cd "${PROJECT_ROOT}"
mkdir -p "${PROJECT_ROOT}/.build/module-cache" "${PROJECT_ROOT}/.build/swiftpm-cache"
SWIFTPM_MODULECACHE_OVERRIDE="${PROJECT_ROOT}/.build/module-cache" \
CLANG_MODULE_CACHE_PATH="${PROJECT_ROOT}/.build/module-cache" \
swift build \
    --disable-sandbox \
    --cache-path "${PROJECT_ROOT}/.build/swiftpm-cache" \
    -c release

if [[ "${APP_DIR}" != "${PROJECT_ROOT}/dist/Mail Sentinel.app" ]]; then
    echo "Chemin d'application inattendu" >&2
    exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${CONTENTS_DIR}/MacOS" "${CONTENTS_DIR}/Resources"
cp "${PROJECT_ROOT}/.build/release/MailSentinel" "${CONTENTS_DIR}/MacOS/MailSentinel"
cp "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

xattr -cr "${APP_DIR}"
codesign --force --deep --sign - "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"

echo "Application créée : ${APP_DIR}"
