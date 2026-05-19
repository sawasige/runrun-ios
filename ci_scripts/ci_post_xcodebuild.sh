#!/bin/sh
# Xcode Cloud 用: archive アクションの後で dSYM を Firebase Crashlytics にアップロードする。
# Archive ワークフロー以外 (テスト等) では何もしない。

set -euo pipefail

# CI_ARCHIVE_PATH が設定されていない (= archive アクション以外) ならスキップ
if [ -z "${CI_ARCHIVE_PATH:-}" ]; then
    echo "Not an archive action (CI_ARCHIVE_PATH is empty), skipping dSYM upload."
    exit 0
fi

DSYM_DIR="$CI_ARCHIVE_PATH/dSYMs"
if [ ! -d "$DSYM_DIR" ]; then
    echo "WARNING: dSYM directory not found at $DSYM_DIR"
    exit 0
fi

# Firebase Crashlytics SDK 付属の upload-symbols を探す。SPM 経由で導入しているので
# checkouts ディレクトリ配下に存在する。
UPLOAD_SYMBOLS=$(find "$CI_DERIVED_DATA_PATH" -name "upload-symbols" -type f 2>/dev/null | head -1)
if [ -z "$UPLOAD_SYMBOLS" ]; then
    UPLOAD_SYMBOLS=$(find "$CI_PRIMARY_REPOSITORY_PATH" -name "upload-symbols" -type f 2>/dev/null | head -1)
fi
if [ -z "$UPLOAD_SYMBOLS" ]; then
    echo "ERROR: upload-symbols tool not found. Firebase SDK may not be checked out."
    exit 1
fi

GSP="$CI_PRIMARY_REPOSITORY_PATH/RunRun/GoogleService-Info.plist"
if [ ! -f "$GSP" ]; then
    echo "ERROR: GoogleService-Info.plist not found at $GSP"
    exit 1
fi

echo "Uploading dSYMs from $DSYM_DIR to Crashlytics..."
"$UPLOAD_SYMBOLS" -gsp "$GSP" -p ios "$DSYM_DIR"
echo "dSYM upload complete."
