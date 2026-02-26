# ⚡ 快速开始指南

## 🎯 最简单的方式（无需注册）

直接使用Google翻译，无需任何配置：

```bash
python translate.py --google
```

完成！

---

## 🚀 推荐方式（更好的翻译质量）

### 5分钟设置硅基流动API

1. **注册账号**（1分钟）
   - 访问：https://cloud.siliconflow.cn/
   - 用手机号注册（国内手机号）

2. **获取API密钥**（30秒）
   - 登录后点击右上角头像
   - 选择"API密钥管理"
   - 点击"生成新令牌"
   - 复制密钥（格式：sk-xxxxx）

3. **设置环境变量**（1分钟）
   
   **Windows PowerShell：**
   ```powershell
   # 临时设置（关闭窗口后失效）
   $env:SILICONFLOW_API_KEY = "粘贴你的密钥"
   
   # 永久设置（推荐）
   [System.Environment]::SetEnvironmentVariable('SILICONFLOW_API_KEY', '粘贴你的密钥', 'User')
   ```
   
   设置永久变量后，需要重启PowerShell窗口生效。

4. **测试**（30秒）
   ```bash
   python test_api.py
   ```
   
   看到 ✅ 就表示成功了！

5. **开始使用**
   ```bash
   # 自动选择最佳API
   python translate.py
   
   # 或明确指定
   python translate.py --siliconflow
   ```

---

## 💡 使用技巧

### 方式1: AutoHotkey快捷键（最方便）
1. 运行 `instantTrans.exe` 或 `instantTrans_v2.ahk`
2. 选中任何文字
3. 按 `Ctrl+Shift+]`
4. 文字自动替换为翻译结果
5. 右下角显示提示：**✓ 翻译完成 (API名称)**（2.5秒后消失）

### 方式2: 命令行
```bash
# 复制要翻译的文字（Ctrl+C）
# 然后运行
python translate.py

# 翻译结果会自动复制到剪贴板，直接粘贴（Ctrl+V）即可
```

---

## 🎁 免费额度

| API服务 | 每月免费 | 够用吗？ |
|---------|---------|---------|
| 硅基流动 | 500万tokens | ✅ 够翻译约200万字 |
| Google | 无限制 | ✅ 完全免费 |

一般个人使用，免费额度完全够用！

---

## 💡 使用提示

翻译完成后，右下角会显示提示（2.5秒后自动消失）：

| 提示文字 | 说明 |
|---------|------|
| ✓ 翻译完成 (SiliconFlow) | 使用硅基流动API翻译成功 |
| ✓ 翻译完成 (Google) | 使用Google翻译成功 |
| 未选中文字 | 没有选中任何文字 |
| 翻译失败 | 翻译过程出错 |

---

## ❓ 遇到问题？

### 检查API密钥是否设置成功
```powershell
echo $env:SILICONFLOW_API_KEY
```
应该显示你的密钥，如果显示空白表示未设置。

### 运行测试脚本
```bash
python test_api.py
```
会显示详细的测试结果和错误信息。

### 还是不行？
查看详细文档：[SILICONFLOW_SETUP.md](SILICONFLOW_SETUP.md)

---

## 🎉 就是这么简单！

现在你可以：
- ✅ 用快捷键快速翻译任何文字
- ✅ 享受免费的AI翻译质量
- ✅ 无缝集成到日常工作流

Happy translating! 🌍
