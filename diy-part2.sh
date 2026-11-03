#!/bin/bash
# ==========================================================
#  N60 Pro 固件 - feeds install 之后的包选择与配置修补 (大修版)
#  用法: ./diy-part2.sh [minimal|full]
#
#  修复历史问题:
#   - 不依赖 make defconfig 猜测, 包必须真实存在才启用
#   - libffi 3.4.7 交叉编译 fficonfig.h 路径问题的兜底补丁
#   - dnsmasq 与 dnsmasq-full 强制二选一
#   - passwall / ssr-plus 与 OpenClash 冲突, 强制移除
# ==========================================================
set -u

TIER="${1:-full}"
LAN_IP="192.168.5.1"
HOSTNAME="N60Pro"
TIMEZONE="CST-8"

echo "[diy-part2] tier=${TIER}"

# ---------- 工具函数 ----------
find_pkg() {
  find package feeds -maxdepth 5 -type d -name "$1" 2>/dev/null | head -1
}

enable_pkg() {
  local name="$1"
  local path
  path=$(find_pkg "$name")
  if [ -z "$path" ]; then
    echo "  [MISS] $name  (源码中不存在)"
    return 1
  fi
  sed -i "/^CONFIG_PACKAGE_${name}=/d" .config
  sed -i "/^# CONFIG_PACKAGE_${name} is not set/d" .config
  echo "CONFIG_PACKAGE_${name}=y" >> .config
  echo "  [ OK ] $name  <- $path"
  return 0
}

disable_pkg() {
  sed -i "/^CONFIG_PACKAGE_$1=/d" .config
  sed -i "/^# CONFIG_PACKAGE_$1 is not set/d" .config
  echo "# CONFIG_PACKAGE_$1 is not set" >> .config
}

# ---------- 1. 冲突包处理 ----------
echo "[diy-part2] 1. 冲突包处理"
disable_pkg dnsmasq
disable_pkg luci-app-passwall
disable_pkg luci-app-passwall2
disable_pkg luci-app-ssr-plus
disable_pkg luci-app-dockerman
disable_pkg docker
disable_pkg dockerd
echo "  已禁用: dnsmasq(换full) / passwall* / ssr-plus / docker*"

# ---------- 2. libffi 补丁 (关键修复) ----------
echo "[diy-part2] 2. libffi 交叉编译路径修复"

# 用 find 定位, 不硬编码路径
# 注意: package/feeds/packages/libffi 通常是符号链接 -> feeds/packages/libs/libffi
#       sed -i 会破坏符号链接, 必须先 readlink -f 解析真实路径
LIBFFI_LINK=$(find package feeds -maxdepth 5 -type d -name libffi 2>/dev/null | head -1)
LIBFFI_MK=""

if [ -n "$LIBFFI_LINK" ]; then
  echo "  定位到: $LIBFFI_LINK"
  # 解析符号链接真实路径
  LIBFFI_REAL=$(readlink -f "$LIBFFI_LINK")
  echo "  真实路径: $LIBFFI_REAL"
  for cand in "$LIBFFI_REAL/Makefile" "$LIBFFI_LINK/Makefile"; do
    if [ -f "$cand" ]; then LIBFFI_MK="$cand"; break; fi
  done
fi

if [ -n "$LIBFFI_MK" ]; then
  echo "  使用 Makefile: $LIBFFI_MK"
  cp "$LIBFFI_MK" "$LIBFFI_MK.n60bak"

  # 问题: 24.10 的 libffi Makefile 写的是
  #   $(CP) $(PKG_BUILD_DIR)/$(GNU_TARGET_NAME)*/fficonfig.h $(1)/usr/include/
  # 但交叉编译时 fficonfig.h 实际生成在 PKG_BUILD_DIR 根或 mediatek/ 子目录,
  # 不匹配 GNU_TARGET_NAME* 通配 -> cp 失败 -> 整包中断
  # 修复: 替换为 make 的 shell 函数实时 find
  if grep -q 'GNU_TARGET_NAME)\*/fficonfig\.h' "$LIBFFI_MK"; then
    sed -i 's|\$(PKG_BUILD_DIR)/\$(GNU_TARGET_NAME)\*/fficonfig\.h|$(shell find $(PKG_BUILD_DIR) -name fficonfig.h -print -quit)|g' "$LIBFFI_MK"
    echo "  已替换 GNU_TARGET_NAME* -> shell find"
  else
    echo "  [warn] 未匹配到 GNU_TARGET_NAME*/fficonfig.h 写法"
  fi

  echo "  补丁后 fficonfig 行:"
  grep -n 'fficonfig' "$LIBFFI_MK" || echo "    (无)"
else
  echo "::error::找不到 libffi Makefile, 无法修补, 中止以避免编译失败"
  exit 1
fi

# ---------- 3. 包选择 ----------
echo "[diy-part2] 3. 包选择"
FAIL=0
enable_pkg luci-app-openclash || FAIL=1
for p in dnsmasq-full ruby ruby-yaml kmod-tun unzip bash curl ca-bundle ip-full; do
  enable_pkg "$p" || echo "  [warn] $p 未找到(可能已内置)"
done

if [ "$TIER" = "full" ]; then
  echo "[diy-part2] 4. 完整档插件"
  for p in luci-app-lucky luci-app-adguardhome \
           luci-theme-argon luci-app-argon-config \
           luci-app-filetransfer luci-app-ttyd luci-app-upnp \
           luci-app-nlbwmon luci-app-sqm luci-app-wol \
           luci-app-ddns luci-app-autoreboot; do
    enable_pkg "$p" || echo "  [warn] $p 未找到, 跳过"
  done
fi

if [ "$FAIL" = "1" ]; then
  echo "::error::luci-app-openclash 找不到, 中止构建"
  exit 1
fi

# ---------- 5. 默认 LAN IP / 主机名 / 时区 ----------
echo "[diy-part2] 5. 默认 IP/主机名/时区"
if [ -f package/base-files/files/bin/config_generate ]; then
  sed -i "s/192\.168\.1\.1/${LAN_IP}/g" package/base-files/files/bin/config_generate
  sed -i "s/timezone='UTC'/timezone='${TIMEZONE}'/" package/base-files/files/bin/config_generate
  sed -i "s/hostname='ImmortalWrt'/hostname='${HOSTNAME}'/" package/base-files/files/bin/config_generate
  sed -i "s/hostname='OpenWrt'/hostname='${HOSTNAME}'/" package/base-files/files/bin/config_generate
  echo "  LAN=${LAN_IP} host=${HOSTNAME} tz=${TIMEZONE}"
fi
grep -rl '192\.168\.1\.1' package/*/luci-app-*/root/etc/uci-defaults/ 2>/dev/null | \
  xargs -r sed -i "s/192\.168\.1\.1/${LAN_IP}/g" 2>/dev/null || true

# ---------- 6. 主题 ----------
sed -i "s/luci-theme-bootstrap/luci-theme-argon/g" feeds/luci/collections/luci/Makefile 2>/dev/null || true

# ---------- 7. AdGuardHome / OpenClash 端口错开 ----------
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-adguard-openclash-compat << 'UCIEOF'
#!/bin/sh
if [ -f /etc/config/AdGuardHome ]; then
  uci -q set AdGuardHome.AdGuardHome.port='3000'
  uci -q set AdGuardHome.AdGuardHome.dns_port='5353'
  uci -q commit AdGuardHome
fi
if [ -f /etc/config/openclash ]; then
  uci -q set openclash.config.enable_custom_dns='1'
  uci -q set openclash.config.custom_dns_server='127.0.0.1:5353'
  uci -q commit openclash
fi
exit 0
UCIEOF
chmod +x package/base-files/files/etc/uci-defaults/99-adguard-openclash-compat

cat > package/base-files/files/etc/uci-defaults/98-openclash-off << 'UCIEOF'
#!/bin/sh
if [ -f /etc/config/openclash ]; then
  uci -q set openclash.config.enable='0'
  uci -q commit openclash
fi
exit 0
UCIEOF
chmod +x package/base-files/files/etc/uci-defaults/98-openclash-off

# ---------- 8. 最终自检 ----------
echo "[diy-part2] 6. .config 自检"
for p in luci-app-openclash dnsmasq-full; do
  grep -q "^CONFIG_PACKAGE_${p}=y" .config && echo "  OK ${p}" || { echo "::error::${p} 未进入 .config"; exit 1; }
done
grep -q "^CONFIG_PACKAGE_dnsmasq=y" .config && { echo "::error::dnsmasq 冲突"; exit 1; }
grep -E "^CONFIG_TARGET_(BOARD|PROFILE)=" .config || true
echo "[diy-part2] done"