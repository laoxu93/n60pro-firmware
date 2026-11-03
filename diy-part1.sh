#!/bin/bash
# ==========================================================
#  N60 Pro 固件 - feeds 注入 (大修版)
#  用法: ./diy-part1.sh [minimal|full]
#
#  设计原则:
#   - 基础 feeds 全部使用 ImmortalWrt 官方 openwrt-24.10 分支
#   - 不使用 kenzok8 等聚合第三方源(其库版本与 24.10 不匹配,
#     会覆盖基础库导致编译失败, 如 libffi 3.4.7)
#   - 插件按需从各作者官方仓库单独引入
#   - libffi 打补丁兜底
# ==========================================================
set -e

TIER="${1:-full}"
echo "[diy-part1] tier=${TIER}"

# ---------- 第三方插件源(仅插件本身, 不附带基础库) ----------
echo "[diy-part1] 追加插件源..."

# OpenClash (官方: vernesong)
echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default

if [ "$TIER" = "full" ]; then
  # Lucky (官方: gdy666)
  echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git;main' >> feeds.conf.default
  # AdGuardHome (官方: sirpdboy)
  echo 'src-git adguardhome https://github.com/sirpdboy/luci-app-adguardhome.git;main' >> feeds.conf.default
  # Argon 主题 (官方: jerrykuku)
  echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git;master' >> feeds.conf.default
  echo 'src-git argonc https://github.com/jerrykuku/luci-app-argon-config.git;master' >> feeds.conf.default
  echo "[diy-part1] full: +lucky +adguardhome +argon"
fi

echo "[diy-part1] 当前 feeds:"
cat feeds.conf.default
echo "[diy-part1] done"
