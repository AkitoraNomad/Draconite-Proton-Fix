# 《龙晶》Linux 启动与字体修复

这个社区补丁适用于在 Linux 上通过 Steam 游玩《龙晶》（App ID `4337080`）时遇到的两个问题：

- 启动时报「无法完成文件验证」，详情为 `WORKER_PRIORITY_FAILED (OS 87.0)`。
- 部分简体中文和播放、停止符号显示为方框，例如「所□□公室」。

仓库包含已编译的 Wine DLL、符号字体、安装脚本和对应源码，支持 **x86-64 Linux，安装时无需编译**。

## 安装

1. 下载本仓库的 ZIP 并完整解压，或克隆本仓库。在包含 `install.sh`、`files/` 和 `source/` 的项目根目录打开终端。Steam Deck 请在桌面模式下操作。
2. 使用运行 Steam 的普通用户执行以下命令，不要使用 `sudo`：

   ```bash
   bash install.sh
   ```

   脚本会复用 Steam 兼容工具目录中已安装且通过校验的原版 **GE-Proton 11-12 x86-64**，也识别 ProtonPlus 的 `Proton-GE Latest` 目录。若找不到匹配版本，脚本会从 [GE-Proton 11-12 发布页](https://github.com/GloriousEggroll/proton-ge-custom/releases/tag/GE-Proton11-12) 下载约 **541 MiB** 的原版包。首次安装请预留约 **2.5 GiB** 空间。
3. 完全退出并重新打开 Steam。右键《龙晶》→ 属性 → 兼容性，勾选「强制使用特定的 Steam Play 兼容工具」，选择 **`Draconite-Proton-GE-11-12`**，然后用「玩 龙晶」启动。

安装脚本会识别原生 Steam 和 Flatpak Steam 的常见数据目录。如果两者同时存在，需要用 `--steam-root` 指定要安装到哪个 Steam，例如：

```bash
bash install.sh --steam-root "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
```

也可以用 `--archive` 指定已下载的官方 GE-Proton 压缩包；这两个参数可以组合使用：

```bash
bash install.sh --archive /path/to/GE-Proton11-12-x86_64.tar.gz
```

如果装过只有启动修复的版本，先退出 Steam，把脚本提示的 `Draconite-Proton-GE-11-12` 目录移到 `compatibilitytools.d` 之外，再重新运行安装脚本。

## 验证情况

- 启动修复已在 **Arch Linux、原生 Steam、《龙晶》Build `26593543`** 上验证，使用默认启动选项可进入主菜单。
- 字体修复已用独立的 GE-Proton 11-12 环境验证。屏蔽宿主机字体后，DirectWrite 能为「长」「办」、`▶`、`◼` 找到字形，线程优先级也能正常降低和恢复。字体修复尚未在游戏画面中验证。

Steam Deck 和 Flatpak Steam 的路径已纳入安装脚本，但尚未验证 Steam Deck 实机和 Flatpak Steam 下的游戏启动。

## 恢复与卸载

在《龙晶》的兼容性设置里切回原来的 Proton，即可停止使用补丁。要移除这个工具，可退出 Steam 并删除安装脚本显示的 `Draconite-Proton-GE-11-12` 目录。

安装脚本只在所选 Steam 的 `compatibilitytools.d` 中安装独立工具，保留现有 Proton、游戏文件和存档。

## 修复原理

游戏自检在读取文件前请求 Windows 的线程后台模式。原版 Proton 对该请求返回错误 87，游戏因此中止校验。

补丁为 `kernelbase.dll` 中的 `SetThreadPriority` 补充 `THREAD_MODE_BACKGROUND_BEGIN` / `THREAD_MODE_BACKGROUND_END` 处理，让校验线程在后台模式下以较低的 CPU 优先级运行，退出后台模式时恢复原值。文件校验仍由游戏执行。

此补丁实现后台模式的 CPU 优先级行为；Windows 后台模式还涉及 I/O 和内存优先级。接口说明见 [微软 SetThreadPriority 文档](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setthreadpriority)。

原版 DirectWrite 对 `zh-CN` 等简体中文语言标签可能回退到 MS Gothic。这款日文字体能显示「所」「公」「室」，但缺少「长」「办」。`dwrite.dll` 补丁让这些语言标签使用简体中文回退，并为播放、停止符号加入随兼容工具提供的 Noto Sans Symbols 2，无需安装系统字体。

## 源码与构建

普通玩家直接运行安装脚本即可。维护者可在 [source/](source/) 中查看对应源码和补丁：

- `wine-fda79a5.tar.gz`：Valve Wine 源码快照，基础提交为 [`fda79a585939fb7512dc220a11249f9ffe825fcf`](https://github.com/ValveSoftware/wine/tree/fda79a585939fb7512dc220a11249f9ffe825fcf)。
- [ge-version-info.patch](source/ge-version-info.patch)：GE 版本信息补丁。
- [Draconite-thread-priority.patch](source/Draconite-thread-priority.patch)：本项目的线程优先级补丁。
- [Draconite-font-fallback.patch](source/Draconite-font-fallback.patch)：本项目的 DirectWrite 字体回退补丁。
- [build.sh](source/build.sh)：DLL 构建脚本。
- [LICENSE](source/LICENSE)、[COPYING.LIB](source/COPYING.LIB) 和 [AUTHORS](source/AUTHORS)：Wine 许可说明、LGPL 许可文本及作者名单。

随包字体为 [Noto Sans Symbols 2](https://github.com/notofonts/symbols) 2.008，许可见 [SIL Open Font License 1.1](files/Draconite-NotoSansSymbols2-OFL.txt)。

重建 DLL 需要 GCC、MinGW-w64（x86-64 和 i686）、GNU Make、Autoconf、Bison、Flex，以及 Wine 配置所需的开发依赖。在项目根目录运行：

```bash
bash source/build.sh
```

默认构建目录为当前目录下的 `wine-draconite-build/`。脚本完成后会输出 `kernelbase.dll` 和 `dwrite.dll` 的路径。重新打包时，把新 DLL 复制到 `files/`，并同步更新安装脚本里的 SHA-256。
