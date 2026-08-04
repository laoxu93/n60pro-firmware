#!/bin/bash
# ============================================================
#  N60 Pro 第三方软件源 (已验证可达, 2026-08)
#  - openclash / passwall / lucky / adguardhome
#  注意: passwall 已搬家到 Openwrt-Passwall 组织
# ============================================================
echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default
echo 'src-git passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git lucky https://github.com/gdy666/luci-app-lucky.git;main' >> feeds.conf.default
echo 'src-git adguardhome https://github.com/sirpdboy/luci-app-adguardhome.git;main' >> feeds.conf.default
echo "[diy-part1] feeds appended: openclash/passwall/lucky/adguardhome"
