#!/bin/bash
# ランディングページ用アセットを更新するスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$PROJECT_ROOT/docs"
ASSETS_DIR="$DOCS_DIR/assets"

mkdir -p "$ASSETS_DIR"

echo "Copying logo..."
cp "$PROJECT_ROOT/RunRun/Assets.xcassets/Logo.imageset/Logo.png" "$ASSETS_DIR/logo.png"

echo "Copying screenshots..."
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-01_Timeline_framed.png" "$ASSETS_DIR/screenshot1.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-02_Records_framed.png" "$ASSETS_DIR/screenshot2.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-03_MonthDetail_framed.png" "$ASSETS_DIR/screenshot3.png"

echo "Done! Assets copied to $ASSETS_DIR"
