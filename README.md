# instantTrans

> - 支持**免费 AI 翻译 API**：DeepSeek、硅基流动（SiliconFlow）  
> - 鼠标选中文字后，在指针附近显示**翻译 / 润色 / 回复**工具条
> - 把选中的文字快速**中英互译**，并替换之前选中的文字  
> - 支持多种风格润色，以及根据选中的聊天上下文生成 3 条建议回复
> - AI 翻译支持双向翻译，自动识别语言  
> - 兼容 Python 3.13+ / 3.14  
> - 支持 **Windows**（AutoHotkey）与 **macOS**（PopClip）

## ✨ 特性

- 🎯 **多服务支持**：DeepSeek + 硅基流动 + Google + 本地模型（HY-MT1.5）
- 🖥️ **本地离线翻译**：基于 [HY-MT1.5-1.8B-ONNX](https://huggingface.co/onnx-community/HY-MT1.5-1.8B-ONNX)，无需联网、无需 API 密钥
- 🖱️ **托盘 / PopClip 菜单**：Windows 任务栏托盘或 macOS PopClip 中切换默认翻译服务
- 🔄 **智能降级**：DeepSeek → 硅基流动 → Google → 本地模型，失败时自动切换
- 🆓 **完全免费**：所有方案都免费可用
- 🖱️ **划词工具条**：Windows 中鼠标拖选文字后直接选择翻译、润色或建议回复
- 🌍 **智能互译**：自动识别中英文并翻译为对应语言
- 💡 **即时反馈**：翻译后显示使用的服务（Windows 2.5 秒提示）

## 🚀 快速开始

### 1. 克隆仓库

```shell
git clone https://github.com/aaronfang/instantTrans.git
cd instantTrans
```

### 2. 安装依赖

#### Windows

以**管理员身份**运行（推荐，会一并配置本地模型环境）：

```shell
install.bat
```

或手动安装在线翻译依赖：

```shell
pip install -r requirements.txt
```

#### macOS

需要已安装 [PopClip](https://www.popclip.app/) 与 Python 3.13+。本地模型（`--with-local`）目前需 **Python 3.13**（3.14 暂不支持 `transformers`）。在仓库根目录执行：

```bash
chmod +x install-mac.sh
./install-mac.sh
```

可选：

```bash
./install-mac.sh --with-local      # 同时安装本地模型依赖
./install-mac.sh --api-key-setup   # 交互式配置 API 密钥
```

> 若出现 `bad interpreter: /bin/bash^M`，说明脚本为 Windows 换行符，请执行：
> `sed -i '' 's/\r$//' install-mac.sh` 后重试，或下载最新 Release 包。

安装完成后，PopClip 会提供 **翻译、润色、建议回复** 三个操作。详见 [popclip/README.md](popclip/README.md)。

或手动安装在线翻译依赖：

```bash
pip3 install -r requirements.txt
```

### 3. 配置 API 密钥（可选）

#### 方案 A：在线 API（推荐，国内稳定）

支持 **DeepSeek** 与 **硅基流动**，任选其一或同时配置：

| 服务 | 注册 | 环境变量 |
|------|------|----------|
| DeepSeek | https://platform.deepseek.com/ | `DEEPSEEK_API_KEY` |
| 硅基流动 | https://cloud.siliconflow.cn/ | `SILICONFLOW_API_KEY` |

PowerShell 永久设置示例（Windows）：

```powershell
[System.Environment]::SetEnvironmentVariable('SILICONFLOW_API_KEY', 'sk-xxxxxx', 'User')
# 或
[System.Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'sk-xxxxxx', 'User')
```

macOS 写入 `~/.zshrc` 示例：

```bash
export DEEPSEEK_API_KEY='sk-xxxxxx'
# 或
export SILICONFLOW_API_KEY='sk-xxxxxx'
```

也可在 macOS 上运行 `./install-mac.sh --api-key-setup`，将密钥写入 `~/.config/instanttrans/config`（PopClip 扩展会读取）。

> 通过 Windows `[User]` 永久设置后，下次翻译即可生效，无需重启 AHK。

> 💡 **不想注册？** 选择「自动」模式即可，程序会依次尝试 Google 与本地模型，无需配置 API 密钥。

#### 方案 B：本地模型（完全离线，无需 API 密钥）

基于腾讯混元 [HY-MT1.5-1.8B-ONNX](https://huggingface.co/onnx-community/HY-MT1.5-1.8B-ONNX) 模型，在本机运行，无需联网、无需密钥。

1. 安装本地模型依赖（额外依赖，体积较大）：

```shell
pip install -r requirements-local.txt
```

2. 首次使用会自动从 Hugging Face 下载模型（约 1~2 GB），之后离线可用。
3. 命令行测试：

Windows：

```shell
echo "Hello World" | clip
python translate.py --local
Get-Clipboard
```

macOS：

```bash
python3 translate.py --text "Hello World" --local --stdout
```

> 💡 可通过环境变量自定义：
> - `HY_MT_MODEL_ID`：更换模型仓库（默认 `onnx-community/HY-MT1.5-1.8B-ONNX`）
> - `HY_MT_ONNX_FILE`：指定 onnx 量化文件（默认优先 `model_q4.onnx`）
>
> ⚠️ 本地模型为离线运行，首次加载较慢；纯 CPU 环境下翻译速度慢于在线 API。

### 选择默认翻译服务

#### Windows（托盘菜单）

运行 `instantTrans_v2.ahk` 后，**右键点击任务栏托盘图标**即可选择默认翻译服务：

| 菜单项 | 说明 |
|--------|------|
| 自动 (智能降级) | DeepSeek → 硅基流动 → Google → 本地模型 自动降级 |
| DeepSeek API | 使用 DeepSeek 在线翻译 |
| 硅基流动 API | 使用 SiliconFlow 在线翻译 |
| Google 翻译 | 使用 Google 翻译 |
| 本地模型 (HY-MT1.5) | 完全离线的本地模型翻译 |

选择后会自动保存到 `config.ini`，下次启动仍生效。

#### macOS（PopClip 扩展设置）

安装 `install-mac.sh` 后，在 PopClip 中打开 **instantTrans** 扩展设置，可以配置翻译服务、润色/回复服务、润色风格和回复意图。

### 4. 使用

#### 方式 1：划词快捷操作（推荐）

**Windows** — 需要 [AutoHotkey v2](https://www.autohotkey.com/)。开发版请运行 `instantTrans_v2.ahk`；
仓库中已有的 `instantTrans_v2.exe` 不包含本次源码改动，使用前需要重新编译，然后：

1. 选中任何文字
2. 松开鼠标后，指针附近会显示「翻译 / 润色 / 回复」工具条
3. 点击「翻译」或「润色」，结果会尝试替换原选区
4. 选择聊天上下文后点击「回复」，会显示 3 条候选回复；点击候选旁的「复制」后手动粘贴到输入框
5. 可以在建议回复窗口填写“我想表达什么”，点击“重新生成”细化回复方向

润色与建议回复需要 DeepSeek 或硅基流动。若当前翻译服务是 Google 或本地模型，
工具会自动尝试已配置的 DeepSeek / 硅基流动服务。

Windows 托盘右键菜单中的“显示系统通知”可以关闭完成、复制、服务切换等系统通知；
处理进度和错误信息仍会保留，避免操作失败时没有反馈。

> Windows 无法像浏览器一样收到所有软件的文字选区事件。当前版本默认支持鼠标拖选；
> 使用键盘 `Shift + 方向键` 形成的选区不会自动显示工具条。

为避免双击按钮、列表项或文件时误弹工具条，默认只响应鼠标拖选。可在 Windows
托盘右键菜单中开启“双击选词时显示”，恢复双击单词后显示工具条。

为避免在资源管理器拖文件或在 3D 软件中拖模型时误触发，默认还会检查鼠标是否为
文本输入光标，并拒绝包含 Windows 文件列表格式的剪贴板内容。若某个自绘软件仍然
误触发，可先在该软件中点击一次，再从托盘菜单选择“暂停/恢复最近使用的应用”。
排除名单会保存在本机 `config.ini` 中。

**macOS** — 需要 [PopClip](https://www.popclip.app/)。运行 `install-mac.sh` 安装扩展后：

1. 选中任何文字
2. 点击 PopClip 弹出的 **翻译**、**润色**或**建议回复**
3. 翻译和润色会替换原选区
4. 建议回复会显示 3 条候选；选择后只复制到剪贴板，需要手动粘贴并确认发送

润色和建议回复需要 DeepSeek 或硅基流动。建议回复只会使用本次明确选中的聊天文字，不读取其他窗口内容，也不会自动发送。

#### 方式 2：命令行

```shell
# 自动选择最佳 API（推荐）
python translate.py

# 指定使用某个服务
python translate.py --deepseek
python translate.py --siliconflow
python translate.py --google
python translate.py --local        # 本地模型（离线）

# 直接传入文本并输出到终端（适合脚本 / PopClip）
python translate.py --text "Hello" --stdout
python translate.py --text "你好" --deepseek --stdout
```

## 📋 支持的翻译 API

| 服务 | 是否需要密钥 | 国内访问 | 速度 | 质量 | 推荐指数 |
|-----|---------|---------|-----|------|----------|
| **DeepSeek** | ✅ 需要 | ✅ 稳定 | ⚡ 快 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **硅基流动** | ✅ 需要 | ✅ 稳定 | ⚡ 快 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Google** | ❌ 免费 | ✅ 稳定 | 🐢 较慢 | ⭐⭐⭐ | ⭐⭐⭐ |
| **本地模型 (HY-MT1.5)** | ❌ 离线 | ✅ 无需联网 | 🐢 取决于硬件 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## 🎯 快捷键 / 操作

| 平台 | 操作 | 功能 |
|------|------|------|
| Windows | 鼠标拖选 / 双击文字 | 显示翻译、润色、回复工具条 |
| macOS | PopClip → 翻译 / 润色 / 建议回复 | 替换翻译或润色结果；选择并复制建议回复 |

## 💡 使用提示

翻译完成后，右下角会显示提示（2.5 秒后自动消失）：

| 提示文字 | 说明 |
|---------|------|
| ✓ 翻译完成 (DeepSeek) | 使用 DeepSeek API 翻译成功 |
| ✓ 翻译完成 (SiliconFlow) | 使用硅基流动 API 翻译成功 |
| ✓ 翻译完成 (Local) | 使用本地模型翻译成功 |
| ✓ 翻译完成 (Google) | 使用 Google 翻译成功 |
| 未选中文字 | 没有选中任何文字 |
| 翻译失败 | 翻译过程出错 |

## ⚠️ 常见问题

### Q: 没有 API 密钥怎么办？

**解决**：直接运行，程序会自动降级（DeepSeek → 硅基流动 → Google → 本地模型）。

### Q: 如何指定使用某个 API？

**解决**：

- **命令行**：使用 `--local`、`--deepseek`、`--siliconflow` 或 `--google` 参数
- **Windows AutoHotkey**：托盘右键选择默认服务，或在「自动」模式下按 DeepSeek → 硅基流动 → Google → 本地模型 顺序降级
- **macOS PopClip**：在扩展设置中切换翻译服务、写作服务、润色风格或回复意图

### Q: 翻译质量如何选择？

**解决**：

- **高质量**：配置 DeepSeek 或硅基流动 API 密钥，或使用「自动」模式
- **离线 / 兜底**：本地模型（自动模式下为最后兜底方案）
- **零配置**：选择「自动」或「Google 翻译」，无需 API 密钥

### Q: macOS 上 PopClip 提示未安装？

**解决**：在仓库根目录运行 `./install-mac.sh`，确保 `~/.config/instanttrans/config` 存在且路径正确。

### Q: macOS 安装本地模型报 `No matching distribution found for transformers`？

**解决**：你很可能在使用 **Python 3.14**。`transformers` / `torch` 尚无 Python 3.14 的 PyPI 包。请安装 Python 3.13：

```bash
brew install python@3.13
PATH="/opt/homebrew/opt/python@3.13/bin:$PATH" ./install-mac.sh --with-local
```

或省略 `--with-local`，仅使用在线翻译（自动模式会降级到 Google，无需本地模型）。

### Q: macOS 运行 install-mac.sh 报 `bad interpreter: /bin/bash^M`？

**解决**：脚本被保存为 Windows 换行符（CRLF）。在脚本所在目录执行：

```bash
sed -i '' 's/\r$//' install-mac.sh popclip/instantTrans.popclipext/translate.sh
chmod +x install-mac.sh
```

或重新下载已修复换行符的最新 Release 包。

### Q: macOS 发布包如何获取？

**解决**：在 [Releases](https://github.com/aaronfang/instantTrans/releases) 下载 `instantTrans-macos-*.zip`，解压后执行 `./install-mac.sh`。也可在 macOS 上运行 `scripts/build-macos-release.sh` 自行打包。

## 📦 依赖

**在线翻译**（`requirements.txt`）：

- Python 3.13+
- pyperclip
- deep-translator
- openai

**本地模型**（`requirements-local.txt`，可选）：

- onnxruntime、transformers、torch、sentencepiece、huggingface_hub

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
