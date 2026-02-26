# 🔑 免费AI翻译API设置指南

## 推荐方案对比

| API服务 | 免费额度 | 国内访问 | 注册难度 | 推荐指数 |
|---------|---------|---------|---------|----------|
| **硅基流动** | 500万tokens/月 | ✅ 稳定 | ⭐ 简单 | ⭐⭐⭐⭐⭐ |
| **DeepSeek** | 500万tokens/月 | ✅ 稳定 | ⭐ 简单 | ⭐⭐⭐⭐⭐ |
| **Groq** | 无限制 | ⚠️ 需代理 | ⭐⭐ 中等 | ⭐⭐⭐⭐ |
| **Google翻译** | 无限制 | ✅ 稳定 | - 无需密钥 | ⭐⭐⭐ |

---

## 方案1: 硅基流动 (SiliconFlow) - 🏆 最推荐

### 优势
- ✅ 完全免费，每月500万tokens
- ✅ 国内访问速度快
- ✅ 无需信用卡，手机号即可注册

### 设置步骤

1. **注册账号**
   - 访问: https://cloud.siliconflow.cn/
   - 使用手机号注册

2. **获取API密钥**
   - 登录后访问: https://cloud.siliconflow.cn/account/ak
   - 点击"生成新令牌"
   - 复制生成的密钥（格式: sk-xxxxxx）

3. **设置环境变量**

   **Windows PowerShell (临时):**
   ```powershell
   $env:SILICONFLOW_API_KEY = "sk-xxxxxx"
   ```

   **Windows PowerShell (永久):**
   ```powershell
   [System.Environment]::SetEnvironmentVariable('SILICONFLOW_API_KEY', 'sk-xxxxxx', 'User')
   ```

4. **测试**
   ```bash
   python translate.py --siliconflow
   ```

---

## 方案2: DeepSeek - 🏆 同样推荐

### 优势
- ✅ 完全免费，每月500万tokens
- ✅ 国内访问稳定
- ✅ 翻译质量高

### 设置步骤

1. **注册账号**
   - 访问: https://platform.deepseek.com/
   - 使用邮箱或手机号注册

2. **获取API密钥**
   - 登录后访问: https://platform.deepseek.com/api_keys
   - 点击"创建API Key"
   - 复制生成的密钥

3. **设置环境变量**

   **Windows PowerShell (临时):**
   ```powershell
   $env:DEEPSEEK_API_KEY = "sk-xxxxxx"
   ```

   **Windows PowerShell (永久):**
   ```powershell
   [System.Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'sk-xxxxxx', 'User')
   ```

4. **测试**
   ```bash
   python translate.py --deepseek
   ```

---

## 方案3: Groq - ⚠️ 需要代理

### 优势
- ✅ 完全免费，无限制
- ✅ 速度极快
- ⚠️ 从中国大陆访问需要代理

### 设置步骤

1. **注册账号** (需要代理)
   - 访问: https://console.groq.com/
   - 使用Google账号或邮箱注册

2. **获取API密钥**
   - 登录后访问: https://console.groq.com/keys
   - 点击"Create API Key"
   - 复制生成的密钥

3. **设置环境变量**

   **Windows PowerShell (临时):**
   ```powershell
   $env:GROQ_API_KEY = "gsk_xxxxxx"
   ```

   **Windows PowerShell (永久):**
   ```powershell
   [System.Environment]::SetEnvironmentVariable('GROQ_API_KEY', 'gsk_xxxxxx', 'User')
   ```

4. **测试**
   ```bash
   python translate.py --groq
   ```

---

## 方案4: Google翻译 - 🎯 最简单

### 优势
- ✅ 无需注册
- ✅ 无需API密钥
- ✅ 稳定可靠
- ⚠️ 翻译质量相对AI稍差

### 使用方法
```bash
python translate.py --google
```

---

## 🚀 快速开始

### 自动降级模式（推荐）
程序会自动尝试以下顺序：
1. 硅基流动
2. DeepSeek
3. Groq
4. Google翻译

只需运行：
```bash
python translate.py
```

### 手动指定API
```bash
# 使用硅基流动
python translate.py --siliconflow

# 使用DeepSeek
python translate.py --deepseek

# 使用Groq
python translate.py --groq

# 使用Google
python translate.py --google
```

---

## 🔧 环境变量验证

检查是否已设置：
```powershell
# 检查硅基流动
echo $env:SILICONFLOW_API_KEY

# 检查DeepSeek
echo $env:DEEPSEEK_API_KEY

# 检查Groq
echo $env:GROQ_API_KEY
```

---

## ⚠️ 常见问题

### Q: 403 Forbidden错误
**原因:** API密钥无效、过期或未设置
**解决:** 
1. 检查环境变量是否正确设置
2. 重新生成API密钥
3. 重启命令行窗口

### Q: Groq连接失败
**原因:** 从中国大陆访问受限
**解决:** 
1. 使用代理
2. 切换到硅基流动或DeepSeek

### Q: 所有API都失败
**解决:** 程序会自动回退到Google翻译

---

## 📊 使用建议

1. **日常使用**: 硅基流动 或 DeepSeek（无需代理，稳定）
2. **追求速度**: Groq（需要代理）
3. **临时应急**: Google翻译（无需密钥）
4. **最佳方案**: 同时设置多个API，自动降级

---

## 🔄 更新日志

- 2025-02-26: 添加硅基流动和DeepSeek支持
- 2025-02-26: 使用OpenAI SDK标准接口
- 2025-02-26: 修复Python 3.14兼容性问题
