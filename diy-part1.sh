#!/bin/bash
# ==========================================================
#  N60 Pro 固件 - feeds 注入
#  用法: ./diy-part1.sh [minimal|full]
#  注意: 本脚本只负责"加源", 不改 .config
#        包的选择统一在 diy-part2.sh (feeds install 之后) 处理
# ==========================================================
set -e

TIER="${1:-full}"
echo "[diy-part1] tier=${TIER}"

# ---------- 基础源 ----------
echo 'src-git packs https://github.com/kenzok8/openwrt-packages.git;master' >> feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small.git;master'            >> feeds.conf.default

# ---------- OpenClash ----------
echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default
echo "[diy-part1] +openclash"

if [ "$TIER" = "full" ]; then
  echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git;main' >> feeds.conf.default
  echo 'src-git adguardhome https://github.com/sirpdboy/luci-app-adguardhome.git;main' >> feeds.conf.default
  echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' >> feeds.conf.default
  echo 'src-git argonc https://github.com/jerrykuku/luci-app-argon-config.git;master' >> feeds.conf.default
  echo "[diy-part1] full: +lucky +adguardhome +argon"
fi

echo "[diy-part1] done. feeds.conf.default:"
cat feeds.conf.default
