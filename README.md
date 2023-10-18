# instantTrans
> - 优先使用Azure的Openai服务来翻译选中文字，备用 googletrans package.   
> - 把选中的文字快速`中译英`，并替换之前选中的文字。  
> - Openai服务支持双向翻译，优先使用。  
> - 适用于Windows系统，其他系统未测试。  

| 快捷键       | 功能   |
|-------------|--------|
| `ctrl`+`shift`+`]` | 中译英 |

## 安装(Windows)
1. 克隆当前仓库到本地  
```shell
git clone https://github.com/aaronfang/instantTrans.git
```  

在环境变量中添加：
```shell
AZURE_API_BASE
AZURE_API_KEY
AZURE_API_VERSION
AZURE_DEPLOYMENT_NAME
```

2. 以**管理员身份**运行 `install.bat`，安装依赖包

3. 安装结束后，会自动运行`instantTrans.exe`，此时会在系统托盘中出现一个小图标。（同时会在启动文件夹中创建快捷方式，以便开机启动） 

4. 选中需要翻译的文字，按下快捷键即可翻译  

### 设置SnipDo
1. 下载并安装SnipDo  

2. 在SnipDo的设置中`Create extension` > `Create a script-extension`

3. 在`Script`中输入以下内容
```shell
cd c:\your\path\to\instantTrans
python translate_snipdo.py --openai --message=$PLAIN_TEXT
```
or 使用google翻译服务
```shell
cd c:\your\path\to\instantTrans
python translate_snipdo.py --google --message=$PLAIN_TEXT
```
4. 打开下方的`Advanced settings`，选择`PASTE_RESULT`或者`SHOW_RESULT`, 保存

5. 在`Text extensions`列表中找到刚才创建的extension，开启后即可划词使用

![Image](https://github.com/aaronfang/instantTrans/blob/main/demo_snipdo.gif)
