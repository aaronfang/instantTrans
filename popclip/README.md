# PopClip 扩展

instantTrans 的 macOS [PopClip](https://www.popclip.app/) 扩展，支持：

- 翻译选中文字并替换原选区
- 按指定风格润色文字并替换原选区
- 根据明确选中的聊天上下文生成 3 条建议回复

## 一键安装（推荐）

在仓库根目录执行：

```bash
chmod +x install-mac.sh
./install-mac.sh
```

脚本会自动：

1. 安装 Python 在线翻译依赖
2. 写入 `~/.config/instanttrans/config`（项目路径、Python 路径）
3. 将扩展复制到 PopClip 扩展目录并重启 PopClip

可选参数：

```bash
./install-mac.sh --with-local      # 同时安装本地模型依赖
./install-mac.sh --api-key-setup   # 交互式写入 API 密钥到配置文件
```

## 手动安装扩展

若已通过 `install-mac.sh` 配置好 `~/.config/instanttrans/config`，可单独安装扩展：

1. 双击 `instantTrans.popclipext`（或解压 `.popclipextz` 后双击）
2. 在 PopClip 中允许加载未签名扩展（安装脚本会自动设置）

## 使用

1. 选中任意文字
2. 点击 PopClip 中需要的操作：
   - **翻译**：将选中内容替换为译文
   - **润色**：将选中内容替换为润色结果
   - **建议回复**：显示 3 条候选回复
3. 建议回复只有在选择候选项后才会复制到剪贴板，需要手动粘贴并确认发送

建议回复只会把本次明确选中的聊天文字发送给模型，不会读取未选中的窗口内容，也不会自动发送消息。

润色和建议回复需要配置 DeepSeek 或硅基流动 API 密钥。可运行：

```bash
./install-mac.sh --api-key-setup
```

在 PopClip 扩展设置中可以配置：

- **翻译服务**：自动降级 / DeepSeek / 硅基流动 / Google / 本地模型
- **润色/回复服务**：自动降级 / DeepSeek / 硅基流动
- **润色风格**：自然 / 简洁 / 专业 / 友好 / 有说服力
- **回复意图**：自动判断 / 赞同 / 继续话题 / 幽默 / 礼貌 / 婉拒 / 共情

## 文件说明

| 文件 | 说明 |
|------|------|
| `Config.json` | PopClip 扩展配置 |
| `translate.sh` | 调用 `translate.py --text ... --stdout` |
| `polish.sh` | 调用统一写作引擎润色文字 |
| `suggest-reply.sh` | 生成候选回复并打开 macOS 选择窗口 |
| `popclip_runner.py` | PopClip 与 `assistant_engine.py` 之间的桥接程序 |

## 调试

```bash
defaults write com.pilotmoon.popclip EnableExtensionDebug -bool YES
```

然后在「控制台」中筛选 Process `PopClip`、Category `Extension`。
