#!/bin/bash
# ==========================================================
#  N60 Pro 固件 - 编译前最后一轮配置文件级修改
#  此脚本在 feeds install -a 之后执行
# ==========================================================
set -e
echo "[diy-part2] start"

LAN_IP="192.168.5.1"
HOSTNAME="N60Pro"
TIMEZONE="CST-8"

# ---------- 1. 默认 LAN IP ----------
sed -i "s/192\.168\.1\.1/${LAN_IP}/g" package/base-files/files/bin/config_generate 2>/dev/null || true
grep -rl '192\.168\.1\.1' package/*/luci-app-*/root/etc/uci-defaults/ 2>/dev/null |   xargs -r sed -i "s/192\.168\.1\.1/${LAN_IP}/g" || true

# ---------- 2. 默认主机名 ----------
sed -i "s/OpenWrt/${HOSTNAME}/g" package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i "s/ImmortalWrt/${HOSTNAME}/g" package/base-files/files/bin/config_generate 2>/dev/null || true

# ---------- 3. 默认时区 ----------
sed -i "s/timezone='UTC'/timezone='${TIMEZONE}'/" package/base-files/files/bin/config_generate 2>/dev/null || true
sed -i "s/timezone='CST-8'/timezone='${TIMEZONE}'/" package/base-files/files/bin/config_generate 2>/dev/null || true

# ---------- 4. 主题 ----------
sed -i "s/luci-theme-bootstrap/luci-theme-argon/g" feeds/luci/collections/luci/Makefile 2>/dev/null || true

# ---------- 5. 精简 ----------
for p in luci-app-dockerman docker dockerd; do
  sed -i "s/^CONFIG_PACKAGE_${p}=y/# CONFIG_PACKAGE_${p} is not set/" .config || true
done

# ---------- 6. AdGuardHome / OpenClash 端口错开 ----------
# AdGuardHome 监听 5353, OpenClash 用 Fake-IP 接管 53 后转发到 5353, 避免抢 53 断网
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-adguard-openclash-compat << 'EOF'
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
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-adguard-openclash-compat

# ---------- 7. 首次开机不自动启动 OpenClash ----------
# 避免首次刷机节点没配好导致断网
cat > package/base-files/files/etc/uci-defaults/98-openclash-off << 'EOF'
#!/bin/sh
if [ -f /etc/config/openclash ]; then
  uci -q set openclash.config.enable='0'
  uci -q commit openclash
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/98-openclash-off

echo "[diy-part2] done (LAN=${LAN_IP}, host=${HOSTNAME}, tz=${TIMEZONE})"
