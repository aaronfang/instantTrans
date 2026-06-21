# PopClip 扩展

instantTrans 的 macOS [PopClip](https://www.popclip.app/) 扩展，实现划词翻译并替换选中文字。

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
2. 点击 PopClip 的 **instantTrans** 按钮
3. 选中内容将替换为译文

在 PopClip 扩展设置中可切换「翻译服务」：自动降级 / DeepSeek / 硅基流动 / Google / 本地模型。

## 文件说明

| 文件 | 说明 |
|------|------|
| `Config.json` | PopClip 扩展配置 |
| `translate.sh` | 调用 `translate.py --text ... --stdout` |

## 调试

```bash
defaults write com.pilotmoon.popclip EnableExtensionDebug -bool YES
```

然后在「控制台」中筛选 Process `PopClip`、Category `Extension`。
