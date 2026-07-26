# Loongnix 25 Hermes 部署包

这是一套面向 LoongArch64（Loongnix 软件包架构名为 `loong64`）的分阶段脚本。默认把源码、虚拟环境和构建缓存放在 `/data/hermes`，避免挤占根分区。

先复制配置：

```bash
cp config/deploy.env.example config/deploy.env
```

推荐执行顺序：

```bash
bash scripts/00-preflight.sh
sudo bash scripts/10-install-system-deps.sh
bash scripts/20-install-hermes-core.sh
bash scripts/30-configure-deepseek.sh
bash scripts/40-install-browser.sh
bash scripts/50-build-dashboard.sh             # 可选
bash scripts/60-install-computer-use.sh         # 可选
bash scripts/61-install-ydotool.sh              # Computer Use 键鼠输入需要
bash scripts/70-prepare-electron31-dev.sh        # 实验性，可选
bash scripts/71-run-electron31-dev.sh            # 启动 Electron 31 开发版
bash scripts/90-verify.sh
```

原则：

- 不自动创建、格式化或合并分区；
- 不在脚本中保存任何示例 API Key；
- 会改系统软件包的阶段明确要求 `sudo`，其余构建均由普通用户执行；
- 版本、提交和关键下载均固定；已有源码目录有未提交改动时立即停止；
- Electron 31.7.7 仅是“开发版启动”方案，不等于已产出可分发安装包。

## 实机截图

![Hermes Desktop 实机界面](images/hermes-desktop.png)

![Loongnix 25 Hermes 实机验证](images/hermes-system-info.png)

## 安全说明

- 仓库只提供 `config/deploy.env.example`，不要提交实际的 `config/deploy.env`；
- API Key 由 `30-configure-deepseek.sh` 在终端静默读取；
- 运行日志、构建缓存、虚拟环境和私有环境文件不应提交；
- `ydotoold` 可以注入桌面输入，部署时应保持 Socket 仅对目标桌面用户可访问。

详细解释见 [CSDN-龙芯Loongnix25部署Hermes完整实战.md](./CSDN-龙芯Loongnix25部署Hermes完整实战.md)。
