# 《龙晶》Linux 启动报错 WORKER_PRIORITY_FAILED（OS 87.0）的免编译修复

如果你在 Linux 上通过 Steam 启动《龙晶》，进主菜单时弹出「无法完成文件验证」，详情是 `WORKER_PRIORITY_FAILED (OS 87.0)`，可以用这个社区版 Proton 修复。

下载地址【发布时替换为 ZIP 链接】

1. 下载并完整解压 **Draconite-Proton-Fix-x86_64.zip**。
2. 在解压出来的文件夹中打开终端，运行 `bash install.sh`。Steam Deck 请在桌面模式下操作。脚本会复用本机的原版 GE-Proton 11-12 x86-64，或者自动从 GE 的 GitHub 发布页下载约 541 MiB 的原版包。
3. 完全退出并重启 Steam。在《龙晶》→ 属性 → 兼容性里勾选「强制使用特定的 Steam Play 兼容工具」，选 **`Draconite-Proton-GE-11-12`**，然后点「玩 龙晶」。

游戏在开始校验之前会尝试降低校验线程的优先级，原版 Proton 对这个请求返回错误 87。这个补丁修的是线程优先级，游戏仍会正常校验安装文件。安装包包含源码，安装时无需编译。

已在 Arch Linux 原生 Steam 上验证，《龙晶》Build `26593543` 可用默认启动选项进入主菜单。Steam Deck 实机和 Flatpak Steam 尚未验证。要恢复，只需在《龙晶》的兼容性设置里切回原来的 Proton。

ZIP 的 SHA-256 为 `cbc14582dc6e26167e5c832237f768c198b30a090be7f434decacec75ef230b9`。
