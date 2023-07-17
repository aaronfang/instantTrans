# instantTrans
> 使用 googletrans package 把选中的文字快速`中译英`或者`英译中`，并替换之前选中的文字。

| 快捷键       | 功能   |
|-------------|--------|
| `ctrl`+`shift`+`[` | 英译中 |
| `ctrl`+`shift`+`]` | 中译英 |

## 安装(MacOS)
1. 克隆分支仓库`macos`到本地  
```shell
git clone -b macos https://github.com/aaronfang/instantTrans.git
```  
2. 保存你的服务。(服务通常保存在`/Users/aaronfang/Library/Services/instant_trans.workflow`)
3. 打开`系统偏好设置 -> 键盘 -> 快捷键 -> 服务 -> text`，为你的服务分配一个快捷键。（这里我设置的是`ctrl`+`shift`+`[`和`ctrl`+`shift`+`]`）
4. 设置automator 和Terminal 的"Accessibility"（辅助功能）权限: `系统偏好设置 -> 安全性与隐私 -> 辅助功能` 添加 **Automator** 和 **Terminal** 这两个应用的权限。
5. 设置automator 和Terminal 的"Full Disk Access"（完全磁盘访问）权限: `系统偏好设置 -> 安全性与隐私 -> 完全磁盘访问` 添加 **Automator** 和 **Terminal** 这两个应用的权限。
6. 选中需要翻译的文字，按下快捷键即可翻译  

![image](https://github.com/aaronfang/instantTrans/blob/main/demo.gif)
