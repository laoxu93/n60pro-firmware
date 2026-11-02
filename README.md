# N60 Pro 固件自动编译

Netcore N60 Pro (MT7986A, mediatek/filogic) 的 GitHub Actions 云编译配置。

## 设备

| 项 | 值 |
|---|---|
| 设备 | Netcore N60 Pro |
| 芯片 | MediaTek MT7986A (Filogic 830) |
| 设备代号 | `netcore_n60-pro`（官方别名 netis NX62 V1） |
| 源码 | ImmortalWrt `openwrt-24.10`（默认）/ LEDE |
| 默认 LAN IP | **192.168.5.1** |
| 默认主机名 | N60Pro |
| 时区 | CST-8 |

## 插件清单

### 必装
- **luci-app-openclash** — 代理核心（Meta 内核运行时在线下载，不编进固件）
- **luci-app-lucky** — 内网穿透 / DDNS / 反向代理
- **luci-app-adguardhome** — DNS 去广告

### 推荐
- luci-theme-argon + luci-app-argon-config — 主题
- luci-app-filetransfer — LuCI 内文件传输
- luci-app-ttyd — 网页终端
- luci-app-upnp — 内网端口映射
- luci-app-nlbwmon — 按设备流量统计
- luci-app-sqm — 智能队列（防缓冲膨胀）
- luci-app-wol — 网络唤醒
- luci-app-ddns — 动态域名
- luci-app-autoreboot — 定时重启

### 主动排除
- **luci-app-passwall / ssr-plus** — 与 OpenClash 抢 53 端口和 dnsmasq，同时装刷机必断网

## 已处理的关键问题

1. **dnsmasq 冲突**：OpenClash 依赖 `dnsmasq-full`，原配置同时选中 `dnsmasq` 会报依赖冲突。diy-part1.sh 强制二选一。
2. **OpenClash 缺 ruby**：Makefile 依赖 `+ruby +ruby-yaml`，未装会导致编译失败，已在 diy-part1.sh 补齐。
3. **AdGuardHome 与 OpenClash 抢 53**：AdGuardHome 监听 5353，OpenClash Fake-IP 接管 53 后转发到 5353，首次开机自动配置。
4. **首次开机不断网**：OpenClash 默认关闭，避免节点没配好就接管流量导致失联。

## 使用方法

1. 打开仓库 **Actions** → **Build N60Pro Firmware** → **Run workflow**
2. 选择源码（默认 immortalwrt / openwrt-24.10）、插件档位（minimal / full）
3. 构建约 60-120 分钟，完成后自动创建 **Release**，到 Releases 页下载

也支持每周定时构建（周五 18:00 UTC）。

## 刷机步骤

1. **先备份**：进 Breed 或 U-Boot 完整备份原厂固件
2. 下载 Release 里的 **sysupgrade** 包（不要用 factory 包覆盖已有系统）
3. 刷入后等待 2-3 分钟，指示灯闪烁属正常
4. 浏览器访问 `http://192.168.5.1` 进入 LuCI
5. 首次进 **OpenClash** 配置订阅，Meta 内核会在页面里在线下载

## 文件说明

| 文件 | 作用 |
|---|---|
| `.github/workflows/build.yml` | Actions 工作流（17 个步骤） |
| `.config` | 编译配置（目标已锁定 netcore_n60-pro） |
| `diy-part1.sh` | feeds 注入 + 依赖修复 |
| `diy-part2.sh` | 编译前配置修补（IP/主机名/时区/端口） |
