# 🎉 instantTrans v3.0 更新日志

## ✨ 主要改进

### 1. **精简API支持**
只保留两个最实用的翻译API：
- **硅基流动** (SiliconFlow) - 国内免费AI翻译，速度快，质量高
- **Google翻译** - 无需API密钥，备用方案

### 2. **智能降级**
- 默认使用 **SiliconFlow**（需要API密钥）
- 失败时自动切换到 **Google翻译**（无需配置）
- 无缝切换，用户无感知

### 3. **AHK v2 支持**
- 升级到 AutoHotkey v2 语法（`instantTrans_v2.ahk`）
- 保留 AHK v1 兼容版本（`instantTrans.ahk`）
- **新增功能**：翻译后显示2.5秒提示，告知使用的API

### 4. **Python 3.14 兼容**
- 修复 `cgi` 模块移除问题
- 使用 `deep-translator` 替代 `googletrans`
- 完全兼容 Python 3.13+ / 3.14

---

## 🚀 快速开始

### 方案A：使用SiliconFlow（推荐）

**1. 获取API密钥**
```
访问: https://cloud.siliconflow.cn/account/ak
注册并生成API密钥
```

**2. 设置环境变量**
```powershell
# PowerShell（永久设置）
[System.Environment]::SetEnvironmentVariable('SILICONFLOW_API_KEY', 'sk-你的密钥', 'User')
```

**3. 运行程序**
```
双击 instantTrans.exe（AHK v1）
或
双击 instantTrans_v2.ahk（AHK v2，需要先安装AHK v2）
```

**4. 使用快捷键**
- 选中任何文字
- 按 `Ctrl+Shift+]`
- 文字自动替换为翻译结果
- 右下角显示：**✓ 翻译完成 (SiliconFlow)** (2.5秒后消失)

---

### 方案B：只使用Google翻译（无需配置）

**无需任何设置！**
- 不设置 `SILICONFLOW_API_KEY`
- 程序会自动使用Google翻译
- 运行并使用快捷键即可
- 提示显示：**✓ 翻译完成 (Google)**

---

## 📋 版本说明

### instantTrans.ahk (AHK v1)
- ✅ 适用于 AutoHotkey v1.1
- ✅ 编译为 `instantTrans.exe`
- ✅ 开箱即用，无需安装AHK

### instantTrans_v2.ahk (AHK v2)
- ✅ 适用于 AutoHotkey v2.0+
- ✅ 现代化语法
- ✅ 需要安装 AutoHotkey v2

**推荐使用编译版（instantTrans.exe）**

---

## 🎯 使用示例

### 示例1：中译英
```
选中：你好世界
按快捷键：Ctrl+Shift+]
结果：Hello World
提示：✓ 翻译完成 (SiliconFlow)
```

### 示例2：英译中
```
选中：Hello World
按快捷键：Ctrl+Shift+]
结果：你好世界
提示：✓ 翻译完成 (SiliconFlow)
```

### 示例3：自动降级
```
情况：SiliconFlow API密钥未设置或失败
选中：Hello World
按快捷键：Ctrl+Shift+]
结果：你好世界
提示：✓ 翻译完成 (Google)
```

---

## 🔧 命令行使用

### 默认（智能选择）
```bash
python translate.py
# 优先SiliconFlow，失败时使用Google
```

### 明确指定API
```bash
# 使用SiliconFlow
python translate.py --siliconflow

# 使用Google
python translate.py --google
```

### SnipDo集成
```bash
cd c:\your\path\to\instantTrans
python translate_snipdo.py --message=$PLAIN_TEXT
```

---

## ⚙️ 高级配置

### 仅使用Google翻译
不设置 `SILICONFLOW_API_KEY` 环境变量即可。

### 强制使用SiliconFlow
确保设置了 `SILICONFLOW_API_KEY` 环境变量。

### 测试配置
```bash
# 测试SiliconFlow
echo "Hello World" | clip
python translate.py --siliconflow
Get-Clipboard

# 测试Google
echo "Hello World" | clip
python translate.py --google
Get-Clipboard
```

---

## 💡 提示说明

翻译完成后，屏幕右下角会显示提示：

| 提示文字 | 说明 |
|---------|------|
| ✓ 翻译完成 (SiliconFlow) | 使用硅基流动API翻译成功 |
| ✓ 翻译完成 (Google) | 使用Google翻译成功 |
| 未选中文字 | 没有选中任何文字 |
| 翻译失败 | 翻译过程出错 |

**提示会在2.5秒后自动消失，不影响后续操作。**

---

## 🔄 从旧版本升级

如果你之前使用的是包含多个API（Groq、DeepSeek等）的版本：

1. **现有配置仍然有效**
   - `SILICONFLOW_API_KEY` 继续使用
   - 不需要重新设置

2. **移除的API**
   - Groq
   - DeepSeek
   - Azure OpenAI
   - 不影响现有功能

3. **新增功能**
   - 智能降级到Google
   - API使用提示（2.5秒）
   - AHK v2 支持
   - Python 3.14 兼容

---

## ❓ 常见问题

### Q: 没有API密钥怎么办？
**A:** 不用担心！程序会自动使用Google翻译，无需任何配置。

### Q: SiliconFlow和Google哪个好？
**A:** 
- **SiliconFlow**：AI翻译，质量高，自然流畅，速度快
- **Google**：传统翻译，可靠稳定，无需配置

推荐设置SiliconFlow以获得更好的翻译质量。

### Q: 提示显示的API和实际使用的一致吗？
**A:** 完全一致。提示会准确显示实际使用的翻译API。

### Q: 如何调整提示显示时间？
**A:** 编辑 `.ahk` 文件，修改 `SetTimer` 中的 `-2500` 参数（单位：毫秒）。

### Q: AHK v1 和 v2 有什么区别？
**A:** 
- **v1**：经典版本，编译为exe，开箱即用
- **v2**：现代版本，语法更清晰，需要安装AHK v2

推荐使用编译好的 `instantTrans.exe`（基于v1）。

---

## 📦 依赖

```
pyperclip
deep-translator
openai
```

安装：
```bash
pip install -r requirements.txt
```

---

## 🎯 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+Shift+]` | 翻译选中文字并替换 |

---

## 🔧 技术改进

### Python代码优化
- 使用 OpenAI SDK 统一接口
- 添加完整的类型注解
- 优化错误处理和降级逻辑
- 修复所有代码警告

### AutoHotkey脚本
- 升级到 v2 语法（保持 v1 兼容）
- 添加 API 使用提示功能
- 优化剪贴板保护机制
- 改进错误提示

---

## 📝 完整功能列表

### ✅ 核心功能
- [x] SiliconFlow API支持
- [x] Google翻译支持
- [x] 智能降级机制
- [x] 快捷键翻译（Ctrl+Shift+]）
- [x] API使用提示（2.5秒）
- [x] 中英文自动识别
- [x] 剪贴板保护

### ✅ 兼容性
- [x] Python 3.13+ / 3.14
- [x] AutoHotkey v1.1
- [x] AutoHotkey v2.0+
- [x] Windows 10/11

### ✅ 集成支持
- [x] 命令行使用
- [x] SnipDo集成
- [x] 编译为exe

---

## 📄 文件说明

- `instantTrans.ahk` - AHK v1 版本（可编译为 exe）
- `instantTrans_v2.ahk` - AHK v2 版本（需要 AHK v2 运行时）
- `translate.py` - Python翻译脚本
- `translate_snipdo.py` - SnipDo集成脚本
- `README.md` - 完整说明文档
- `QUICKSTART.md` - 快速开始指南
- `SILICONFLOW_SETUP.md` - API设置指南

---

**版本**: v3.0  
**发布日期**: 2025-02-26  
**更新重点**: 精简API + 智能降级 + Python 3.14兼容

---

**享受快速翻译！** 🎉
