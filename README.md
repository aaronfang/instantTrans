![Image](https://github.com/aaronfang/instantTrans/blob/main/demo_snipdo.gif)


# instantTrans

> - 支持**免费AI翻译API**：硅基流动（SiliconFlow）  
> - 把选中的文字快速`中英互译`，并替换之前选中的文字  
> - AI翻译支持双向翻译，自动识别语言  
> - 兼容 Python 3.13+ / 3.14  
> - 适用于Windows系统

![Demo](https://github.com/aaronfang/instantTrans/blob/main/demo_snipdo.gif)

## ✨ 特性

- 🎯 **双API支持**：硅基流动（AI翻译）+ Google翻译（备用）
- 🔄 **智能降级**：API失败时自动切换备用方案
- 🆓 **完全免费**：所有API都提供免费额度
- ⚡ **快捷操作**：`Ctrl+Shift+]` 一键翻译并替换
- 🌍 **智能互译**：自动识别中英文并翻译为对应语言
- 💡 **即时反馈**：翻译后显示使用的API（2.5秒提示）

## 🚀 快速开始

### 1. 克隆仓库
```shell
git clone https://github.com/aaronfang/instantTrans.git
cd instantTrans
```

### 2. 安装依赖
以**管理员身份**运行：
```shell
install.bat
```
或手动安装：
```shell
pip install -r requirements.txt
```

### 3. 配置API密钥（可选）

#### 方案A：硅基流动（推荐，国内稳定）
1. 注册：https://cloud.siliconflow.cn/
2. 获取密钥：https://cloud.siliconflow.cn/account/ak
3. 设置环境变量：
```powershell
$env:SILICONFLOW_API_KEY = "sk-xxxxxx"
# 或永久设置
[System.Environment]::SetEnvironmentVariable('SILICONFLOW_API_KEY', 'sk-xxxxxx', 'User')
```

> 💡 **不想注册？** 直接使用Google翻译，无需配置！程序会自动降级。

详细设置说明请查看 [SILICONFLOW_SETUP.md](SILICONFLOW_SETUP.md)

### 4. 使用

#### 方式1: AutoHotkey快捷键（推荐）
运行 `instantTrans.exe` 或 `instantTrans_v2.ahk`，然后：
1. 选中任何文字
2. 按 `Ctrl+Shift+]`
3. 文字自动替换为翻译结果
4. 右下角显示提示：**✓ 翻译完成 (API名称)**（2.5秒后消失）

#### 方式2: 命令行
```shell
# 自动选择最佳API（推荐）
python translate.py

# 指定使用某个API
python translate.py --siliconflow
python translate.py --google
```  

## 🔧 SnipDo集成

### 设置SnipDo
1. 下载并安装SnipDo

2. 在SnipDo的设置中 `Create extension` > `Create a script-extension`

3. 在 `Script` 中输入（替换路径）：
```shell
cd c:\your\path\to\instantTrans
python translate_snipdo.py --message=$PLAIN_TEXT
```

或使用Google翻译：
```shell
cd c:\your\path\to\instantTrans
python translate_snipdo.py --google --message=$PLAIN_TEXT
```

4. 打开 `Advanced settings`，选择 `PASTE_RESULT` 或 `SHOW_RESULT`，保存

5. 在 `Text extensions` 列表中启用该扩展，即可划词翻译

## 📋 支持的翻译API

| API | 免费额度 | 国内访问 | 速度 | 质量 | 推荐指数 |
|-----|---------|---------|-----|------|----------|
| **硅基流动** | 500万tokens/月 | ✅ 稳定 | ⚡ 快 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Google** | 无限制 | ✅ 稳定 | 🐢 较慢 | ⭐⭐⭐ | ⭐⭐⭐ |

## 🎯 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+]` | 翻译选中文字并替换 |

## 💡 使用提示

翻译完成后，右下角会显示提示（2.5秒后自动消失）：

| 提示文字 | 说明 |
|---------|------|
| ✓ 翻译完成 (SiliconFlow) | 使用硅基流动API翻译成功 |
| ✓ 翻译完成 (Google) | 使用Google翻译成功 |
| 未选中文字 | 没有选中任何文字 |
| 翻译失败 | 翻译过程出错 |

## ⚠️ 常见问题

### Q: 没有API密钥怎么办？
**解决**: 直接运行，程序会自动使用Google翻译

### Q: 如何指定使用某个API？
**解决**: 
- **命令行**：使用 `--google` 或 `--siliconflow` 参数
- **AutoHotkey**：默认自动选择（优先SiliconFlow，失败则用Google）

### Q: 翻译质量如何选择？
**解决**: 
- **高质量**：设置SiliconFlow API密钥
- **简单快速**：使用Google翻译，无需配置

## 📦 依赖

- Python 3.13+
- pyperclip
- deep-translator
- openai

## 🔄 更新日志

### 2025-02-26 v3.0
- ✨ 精简为两个API：SiliconFlow + Google
- 🔧 使用OpenAI SDK标准接口
- 🐛 修复Python 3.14兼容性问题
- ✨ 翻译后显示2.5秒API使用提示
- ✨ 智能降级机制（SiliconFlow → Google）
- 🗑️ 移除已失效的Azure OpenAI配置

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交Issue和Pull Request！

---

**提示**: 查看 [SILICONFLOW_SETUP.md](SILICONFLOW_SETUP.md) 获取详细的API配置指南
