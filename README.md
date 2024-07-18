# .NET SDK 安装程序 (适用于 OpenWrt)

这是一个用于在 OpenWrt 系统上安装 .NET SDK 的脚本。该脚本将帮助您下载和安装适用于您系统架构的 .NET SDK 版本，并自动配置环境变量。

## 功能

- 自动检测系统架构和 libc 类型
- 检查并安装依赖项（jq 和 ICU）
- 列出可用的 .NET SDK 版本
- 让用户选择要安装的 .NET SDK 版本
- 下载并安装所选版本的 .NET SDK
- 配置环境变量以便使用 .NET SDK

## 使用方法

1. **下载脚本**

   克隆或下载这个仓库到您的 OpenWrt 设备上：
   
   ```sh
   git clone https://github.com/your-username/dotnet-sdk-installer.git
   cd dotnet-sdk-installer
   ```

2. **给予执行权限**

   在终端中运行以下命令来给予脚本执行权限：
   
   ```sh
   chmod +x dotnet-sdk-installer.sh
   ```

3. **运行脚本**

   运行脚本来开始安装过程：
   
   ```sh
   ./dotnet-sdk-installer.sh
   ```

   脚本将提示您选择要安装的 .NET SDK 版本，并处理后续的下载和安装步骤。

4. **完成安装**

   安装完成后，脚本会自动配置环境变量，您可以通过重新登录或手动加载配置文件来使用 .NET SDK：
   
   ```sh
   source ~/.profile
   ```

## 注意事项

- 请确保您的设备可以访问互联网以下载 .NET SDK 和依赖项。
- 该脚本使用 `opkg` 包管理器安装依赖项，如果您使用的是其他包管理器，请根据需要修改脚本。
- 该脚本假定您使用的是 OpenWrt 系统。如果您在其他系统上使用，请根据您的系统环境进行调整。
