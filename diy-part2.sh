#!/bin/bash
# ==========================================================
#  N60 Pro 固件 - feeds install 之后的包选择与配置修补
#  用法: ./diy-part2.sh [minimal|full]
#
#  核心原则:
#   1. 包必须"真实存在于 package/ 目录"才写进 .config
#   2. 不依赖 make defconfig 去猜, 而是 verify 之后才启用
#   3. 任何关键包缺失 -> 直接 exit 1, 不允许生成残缺固件
# ==========================================================
set -u

TIER="${1:-full}"
LAN_IP="192.168.5.1"
HOSTNAME="N60Pro"
TIMEZONE="CST-8"

echo "[diy-part2] tier=${TIER}"

# ---------- 工具函数: 找包真实路径 ----------
find_pkg() {
  # $1 = 包名, 返回 package/ 下相对路径, 找不到返回空
  local name="$1"
  local hits
  hits=$(find package feeds -maxdepth 4 -type d -name "$name" 2>/dev/null | head -1)
  echo "$hits"
}

enable_pkg() {
  local name="$1"
  local path
  path=$(find_pkg "$name")
  if [ -z "$path" ]; then
    echo "  [MISS] $name  (源码中不存在)"
    return 1
  fi
  # 先注释掉已有同名行, 再追加
  sed -i "/^CONFIG_PACKAGE_${name}=/d" .config
  sed -i "/^# CONFIG_PACKAGE_${name} is not set/d" .config
  echo "CONFIG_PACKAGE_${name}=y" >> .config
  echo "  [ OK ] $name  <- $path"
  return 0
}

disable_pkg() {
  local name="$1"
  sed -i "/^CONFIG_PACKAGE_${name}=/d" .config
  echo "# CONFIG_PACKAGE_${name} is not set" >> .config
}

# ---------- 1. 强制冲突处理 ----------
echo "[diy-part2] 1. 冲突包处理"
disable_pkg dnsmasq
disable_pkg luci-app-passwall
disable_pkg luci-app-passwall2
disable_pkg luci-app-ssr-plus
disable_pkg luci-app-dockerman
disable_pkg docker
disable_pkg dockerd
echo "  已禁用: dnsmasq(换full) / passwall* / ssr-plus / docker*"

echo "[diy-part2] 2. OpenClash 及其依赖"
FAIL=0
for p in luci-app-openclash; do
  enable_pkg "$p" || FAIL=1
done
for p in dnsmasq-full ruby ruby-yaml kmod-tun unzip bash curl ca-bundle ip-full; do
  enable_pkg "$p" || echo "  [warn] $p 未找到(可能已内置)"
done

if [ "$TIER" = "full" ]; then
  echo "[diy-part2] 3. 完整档插件"
  for p in luci-app-lucky luci-app-adguardhome \
           luci-theme-argon luci-app-argon-config \
           luci-app-filetransfer luci-app-ttyd luci-app-upnp \
           luci-app-nlbwmon luci-app-sqm luci-app-wol \
           luci-app-ddns luci-app-autoreboot; do
    enable_pkg "$p" || echo "  [warn] $p 未找到, 跳过"
  done
fi

# ---------- 4. 关键包强校验: 缺 OpenClash 直接失败 ----------
if [ "$FAIL" = "1" ]; then
  echo "::error::luci-app-openclash 在上游源码中找不到, 中止构建"
  exit 1
fi

# ---------- 5. 默认 LAN IP / 主机名 / 时区 ----------
echo "[diy-part2] 4. 默认 IP/主机名/时区"
if [ -f package/base-files/files/bin/config_generate ]; then
  sed -i "s/192\.168\.1\.1/${LAN_IP}/g" package/base-files/files/bin/config_generate
  sed -i "s/timezone='UTC'/timezone='${TIMEZONE}'/" package/base-files/files/bin/config_generate
  sed -i "s/hostname='ImmortalWrt'/hostname='${HOSTNAME}'/" package/base-files/files/bin/config_generate
  sed -i "s/hostname='OpenWrt'/hostname='${HOSTNAME}'/" package/base-files/files/bin/config_generate
  echo "  config_generate 已修改: LAN=${LAN_IP} host=${HOSTNAME} tz=${TIMEZONE}"
else
  echo "  [warn] config_generate 不存在, 跳过"
fi

# 第三方包 uci-defaults 里写死的 192.168.1.1
grep -rl '192\.168\.1\.1' package/*/luci-app-*/root/etc/uci-defaults/ 2>/dev/null | \
  xargs -r sed -i "s/192\.168\.1\.1/${LAN_IP}/g" 2>/dev/null || true

# ---------- 6. 主题 ----------
sed -i "s/luci-theme-bootstrap/luci-theme-argon/g" feeds/luci/collections/luci/Makefile 2>/dev/null || true

# ---------- 7. AdGuardHome / OpenClash 端口错开 ----------
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-adguard-openclash-compat << 'UCIEOF'
#!/bin/sh
# AdGuardHome 避开 53 端口, 改用 5353
if [ -f /etc/config/AdGuardHome ]; then
  uci -q set AdGuardHome.AdGuardHome.port='3000'
  uci -q set AdGuardHome.AdGuardHome.dns_port='5353'
  uci -q commit AdGuardHome
fi
# OpenClash 的 DNS 转发到 AdGuardHome
if [ -f /etc/config/openclash ]; then
  uci -q set openclash.config.enable_custom_dns='1'
  uci -q set openclash.config.custom_dns_server='127.0.0.1:5353'
  uci -q commit openclash
fi
exit 0
UCIEOF
chmod +x package/base-files/files/etc/uci-defaults/99-adguard-openclash-compat

# ---------- 8. OpenClash 首次开机默认关闭, 防止断网 ----------
cat > package/base-files/files/etc/uci-defaults/98-openclash-off << 'UCIEOF'
#!/bin/sh
if [ -f /etc/config/openclash ]; then
  uci -q set openclash.config.enable='0'
  uci -q commit openclash
fi
exit 0
UCIEOF
chmod +x package/base-files/files/etc/uci-defaults/98-openclash-off

# ---------- 9. 最终自检 ----------
echo "[diy-part2] 5. .config 关键项自检"
for p in luci-app-openclash dnsmasq-full; do
  if grep -q "^CONFIG_PACKAGE_${p}=y" .config; then
    echo "  OK   ${p}"
  else
    echo "::error::${p} 未进入 .config"
    exit 1
  fi
done
if grep -q "^CONFIG_PACKAGE_dnsmasq=y" .config; then
  echo "::error::dnsmasq 与 dnsmasq-full 同时启用, 会冲突"
  exit 1
fi
grep -E "^CONFIG_TARGET_(BOARD|PROFILE)=" .config || true

echo "[diy-part2] done"
