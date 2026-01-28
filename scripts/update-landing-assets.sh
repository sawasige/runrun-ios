#!/bin/bash
# ランディングページ用アセットを更新するスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$PROJECT_ROOT/docs"
ASSETS_DIR="$DOCS_DIR/assets"
ASSETS_EN_DIR="$DOCS_DIR/en/assets"

mkdir -p "$ASSETS_DIR"
mkdir -p "$ASSETS_EN_DIR"

echo "Copying logo..."
cp "$PROJECT_ROOT/RunRun/Assets.xcassets/Logo.imageset/Logo.png" "$ASSETS_DIR/logo.png"
cp "$PROJECT_ROOT/RunRun/Assets.xcassets/Logo.imageset/Logo.png" "$ASSETS_EN_DIR/logo.png"

echo "Copying Japanese screenshots..."
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-01_Timeline_framed.png" "$ASSETS_DIR/screenshot1.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-02_Records_framed.png" "$ASSETS_DIR/screenshot2.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-03_MonthDetail_framed.png" "$ASSETS_DIR/screenshot3.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-04_RunDetail_framed.png" "$ASSETS_DIR/screenshot4.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-05_FullMap_framed.png" "$ASSETS_DIR/screenshot5.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-06_Leaderboard_framed.png" "$ASSETS_DIR/screenshot6.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-07_Widget1_framed.png" "$ASSETS_DIR/screenshot7.png"
cp "$PROJECT_ROOT/fastlane/screenshots/ja/iPhone 17 Pro Max-08_Widget2_framed.png" "$ASSETS_DIR/screenshot8.png"

echo "Copying English screenshots..."
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-01_Timeline_framed.png" "$ASSETS_EN_DIR/screenshot1.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-02_Records_framed.png" "$ASSETS_EN_DIR/screenshot2.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-03_MonthDetail_framed.png" "$ASSETS_EN_DIR/screenshot3.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-04_RunDetail_framed.png" "$ASSETS_EN_DIR/screenshot4.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-05_FullMap_framed.png" "$ASSETS_EN_DIR/screenshot5.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-06_Leaderboard_framed.png" "$ASSETS_EN_DIR/screenshot6.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-07_Widget1_framed.png" "$ASSETS_EN_DIR/screenshot7.png"
cp "$PROJECT_ROOT/fastlane/screenshots/en-US/iPhone 17 Pro Max-08_Widget2_framed.png" "$ASSETS_EN_DIR/screenshot8.png"

echo "Done! Assets copied to $ASSETS_DIR and $ASSETS_EN_DIR"
