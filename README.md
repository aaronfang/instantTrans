# instantTrans

> - 支持**免费 AI 翻译 API**：DeepSeek、硅基流动（SiliconFlow）  
> - 把选中的文字快速**中英互译**，并替换之前选中的文字  
> - AI 翻译支持双向翻译，自动识别语言  
> - 兼容 Python 3.13+ / 3.14  
> - 支持 **Windows**（AutoHotkey）与 **macOS**（PopClip）

## ✨ 特性

- 🎯 **多服务支持**：DeepSeek + 硅基流动 + Google + 本地模型（HY-MT1.5）
- 🖥️ **本地离线翻译**：基于 [HY-MT1.5-1.8B-ONNX](https://huggingface.co/onnx-community/HY-MT1.5-1.8B-ONNX)，无需联网、无需 API 密钥
- 🖱️ **托盘 / PopClip 菜单**：Windows 任务栏托盘或 macOS PopClip 中切换默认翻译服务
- 🔄 **智能降级**：DeepSeek → 硅基流动 → Google → 本地模型，失败时自动切换
- 🆓 **完全免费**：所有方案都免费可用
- ⚡ **快捷操作**：Windows `Ctrl+Shift+]` / macOS PopClip 一键翻译并替换
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

需要已安装 [PopClip](https://www.popclip.app/) 与 Python 3.13+。在仓库根目录执行：

```bash
chmod +x install-mac.sh
./install-mac.sh
```

可选：

```bash
./install-mac.sh --with-local      # 同时安装本地模型依赖
./install-mac.sh --api-key-setup   # 交互式配置 API 密钥
```

安装完成后，选中文字并点击 PopClip 的 **instantTrans** 按钮即可翻译替换。详见 [popclip/README.md](popclip/README.md)。

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

安装 `install-mac.sh` 后，在 PopClip 中打开 **instantTrans** 扩展设置，可切换「翻译服务」：自动降级 / DeepSeek / 硅基流动 / Google / 本地模型。

### 4. 使用

#### 方式 1：划词快捷操作（推荐）

**Windows** — 需要 [AutoHotkey v2](https://www.autohotkey.com/)。运行 `instantTrans_v2.ahk`（或自行编译为 `instantTrans_v2.exe`），然后：

1. 选中任何文字
2. 按 `Ctrl+Shift+]`
3. 文字自动替换为翻译结果
4. 右下角显示提示：**✓ 翻译完成 (服务名称)**（2.5 秒后消失）

**macOS** — 需要 [PopClip](https://www.popclip.app/)。运行 `install-mac.sh` 安装扩展后：

1. 选中任何文字
2. 点击 PopClip 弹出的 **instantTrans** 按钮
3. 文字自动替换为翻译结果

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
| Windows | `Ctrl+Shift+]` | 翻译选中文字并替换 |
| macOS | PopClip → instantTrans | 翻译选中文字并替换 |

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
- **macOS PopClip**：在扩展设置中切换「翻译服务」

### Q: 翻译质量如何选择？

**解决**：

- **高质量**：配置 DeepSeek 或硅基流动 API 密钥，或使用「自动」模式
- **离线 / 兜底**：本地模型（自动模式下为最后兜底方案）
- **零配置**：选择「自动」或「Google 翻译」，无需 API 密钥

### Q: macOS 上 PopClip 提示未安装？

**解决**：在仓库根目录运行 `./install-mac.sh`，确保 `~/.config/instanttrans/config` 存在且路径正确。

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
