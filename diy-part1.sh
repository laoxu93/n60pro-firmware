#!/bin/bash
# ==========================================================
#  N60 Pro 固件 - feeds 注入
#  用法: ./diy-part1.sh [minimal|full]
#  已验证可达 (2026-11)
# ==========================================================
set -e

TIER="${1:-full}"
echo "[diy-part1] tier=${TIER}"

# ---------- 基础源 ----------
echo 'src-git packs https://github.com/kenzok8/openwrt-packages.git;master' >> feeds.conf.default
echo 'src-git small  https://github.com/kenzok8/small.git;master'            >> feeds.conf.default

# ---------- OpenClash (必带) ----------
echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default

if [ "$TIER" = "full" ]; then
  echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git;main' >> feeds.conf.default
  echo 'src-git adguardhome https://github.com/sirpdboy/luci-app-adguardhome.git;main' >> feeds.conf.default
  echo "[diy-part1] full: +lucky +adguardhome"
fi

# ---------- 关键修复1: dnsmasq 冲突 ----------
sed -i 's/^CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/' .config || true
sed -i 's/^CONFIG_PACKAGE_dnsmasq-full=y/# CONFIG_PACKAGE_dnsmasq-full is not set/' .config || true
grep -q '^# CONFIG_PACKAGE_dnsmasq is not set' .config || echo '# CONFIG_PACKAGE_dnsmasq is not set' >> .config
echo 'CONFIG_PACKAGE_dnsmasq-full=y' >> .config
echo "[diy-part1] dnsmasq -> dnsmasq-full 已处理"

# ---------- 关键修复2: OpenClash 需要 ruby ----------
for p in ruby ruby-yaml kmod-tun ip-full bash curl ca-bundle unzip; do
  grep -q "CONFIG_PACKAGE_${p}=y" .config || echo "CONFIG_PACKAGE_${p}=y" >> .config
done
echo "[diy-part1] openclash 依赖包已补齐"

# ---------- 关键修复3: passwall 与 openclash 冲突 ----------
# 两者都要接管 dnsmasq / nft / 53 端口, 同时安装刷机后必然断网
sed -i 's/^CONFIG_PACKAGE_luci-app-passwall=y/# CONFIG_PACKAGE_luci-app-passwall is not set/' .config || true
sed -i 's/^CONFIG_PACKAGE_luci-app-ssr-plus=y/# CONFIG_PACKAGE_luci-app-ssr-plus is not set/' .config || true
echo "[diy-part1] passwall / ssr-plus 已移除 (与 OpenClash 冲突)"

# ---------- 可选插件 ----------
if [ "$TIER" = "full" ]; then
  for p in luci-theme-argon luci-app-argon-config luci-app-filetransfer            luci-app-ttyd luci-app-upnp luci-app-nlbwmon luci-app-sqm            luci-app-wol luci-app-ddns luci-app-autoreboot; do
    grep -q "CONFIG_PACKAGE_${p}=y" .config || echo "CONFIG_PACKAGE_${p}=y" >> .config
  done
  echo "[diy-part1] 可选插件已追加"
fi

echo "[diy-part1] done"
