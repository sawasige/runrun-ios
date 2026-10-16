#!/bin/bash
# App Store ヘッダー(21:9 3840x1646) / 検索結果(3:2 3840x2560) アセット生成
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
BG=$REPO/docs/assets/og-image.png
FONT_JA=$REPO/fastlane/screenshots/fonts/HiraginoKakuGoBold.ttc
FONT_JA_SUB=$REPO/fastlane/screenshots/fonts/HiraginoMaruGo.ttc
FONT_EN=SF-Pro-Bold
FONT_EN_SUB=SF-Pro

# --- 端末モック: 角丸スクショ + 黒ベゼル + 影 (幅 W px に縮小) ---
# $1 = 元スクショ, $2 = 出力, $3 = 幅
mock() {
  local src=$1 dst=$2 w=$3
  local h=$(( w * 2868 / 1320 ))
  local r=$(( w * 165 / 1320 ))         # 画面角丸
  local b=$(( w * 34 / 1320 ))          # ベゼル幅
  local R=$(( r + b ))
  local W=$(( w + 2*b )) H=$(( h + 2*b ))
  magick "$src" -resize "${w}x${h}!" \
    \( +clone -alpha extract -fill black -colorize 100 -fill white \
       -draw "roundrectangle 0,0,$((w-1)),$((h-1)),$r,$r" \) \
    -alpha off -compose CopyOpacity -composite "$WORK/screen.png"
  magick -size "${W}x${H}" xc:none -fill '#1c1c1e' \
    -draw "roundrectangle 0,0,$((W-1)),$((H-1)),$R,$R" \
    "$WORK/screen.png" -geometry "+${b}+${b}" -compose Over -composite \
    \( +clone -background black -shadow 55x40+0+30 \) +swap -background none -layers merge +repage \
    "$dst"
}

# --- 背景: og-image を指定比率にクロップ→拡大→軽くぼかし→暗めのグラデーション ---
# $1 = 出力, $2 = 幅, $3 = 高さ
backdrop() {
  local dst=$1 W=$2 H=$3
  magick "$BG" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
    -blur 0x14 -modulate 92,105,100 \
    \( -size "${W}x${H}" gradient:'rgba(0,0,0,0.05)-rgba(0,0,0,0.45)' \) -compose Multiply -composite \
    "$dst"
}

# $1 = lang (ja|en)
header() {
  local lang=$1 W=3840 H=1646
  local out="$OUT/header_${lang}.png"
  local loc=ja; [ "$lang" = en ] && loc=en-US
  local font=$FONT_JA fsub=$FONT_JA_SUB t1 t2 s1=150 s2=66 y2=760
  if [ "$lang" = ja ]; then t1='好きなアプリで走るだけ'; t2='ランニング記録を自動で同期、月ごとに振り返り'
  else font=$FONT_EN; fsub=$FONT_EN_SUB; s1=118; s2=60; y2=730; t1='Just run with your favorite app'; t2='Runs sync automatically. Look back month by month.'; fi
  backdrop "$WORK/bg_h.png" $W $H
  local S="$REPO/fastlane/screenshots/$loc/iPhone 17 Pro Max"
  mock "$S-02_Records.png"   "$WORK/p1.png" 560
  mock "$S-01_Timeline.png"  "$WORK/p2.png" 620
  mock "$S-04_RunDetail.png" "$WORK/p3.png" 560
  magick "$WORK/bg_h.png" \
    "$WORK/p1.png" -geometry +2000+330 -composite \
    "$WORK/p3.png" -geometry +3080+330 -composite \
    "$WORK/p2.png" -geometry +2500+200 -composite \
    -gravity NorthWest -fill white \
    -font "$font" -pointsize $s1 -annotate +260+560 "$t1" \
    -font "$fsub" -pointsize $s2 -fill 'rgba(255,255,255,0.92)' -annotate +268+$y2 "$t2" \
    -alpha off "$out"
  echo "wrote $out"
}

search() {
  local lang=$1 W=3840 H=2560
  local out="$OUT/search_${lang}.png"
  local loc=ja; [ "$lang" = en ] && loc=en-US
  local font=$FONT_JA fsub=$FONT_JA_SUB t1 t2 s1=170 s2=76
  if [ "$lang" = ja ]; then t1='好きなアプリで走るだけ'; t2='ランニング記録を自動で同期、月ごとに振り返り'
  else font=$FONT_EN; fsub=$FONT_EN_SUB; s1=160; s2=70; t1='Just run with your favorite app'; t2='Runs sync automatically. Look back month by month.'; fi
  backdrop "$WORK/bg_s.png" $W $H
  local S="$REPO/fastlane/screenshots/$loc/iPhone 17 Pro Max"
  mock "$S-02_Records.png"   "$WORK/q1.png" 900
  mock "$S-01_Timeline.png"  "$WORK/q2.png" 960
  mock "$S-04_RunDetail.png" "$WORK/q3.png" 900
  magick "$WORK/bg_s.png" \
    "$WORK/q1.png" -geometry +420+900 -composite \
    "$WORK/q3.png" -geometry +2460+900 -composite \
    "$WORK/q2.png" -geometry +1410+760 -composite \
    -gravity North -fill white \
    -font "$font" -pointsize $s1 -annotate +0+230 "$t1" \
    -font "$fsub" -pointsize $s2 -fill 'rgba(255,255,255,0.92)' -annotate +0+460 "$t2" \
    -alpha off "$out"
  echo "wrote $out"
}

for l in ja en; do header $l; search $l; done
