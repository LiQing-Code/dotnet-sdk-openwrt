#!/bin/sh

# 自定义安装路径，修改为您希望安装的目录
INSTALL_PATH="$HOME/.dotnet"

# 函数：获取系统架构
get_system_architecture() {
    local sys_type=$(uname -s | awk '{print tolower($0)}')
    local arch=$(uname -m)
    local libc_type

    # 判断是否为 musl libc
    if ldd --version 2>&1 | grep -q 'musl'; then
        libc_type="musl"
    else
        libc_type="glibc"
    fi

    # 输出系统架构类型
    case "$arch" in
        arm*)
            if [ "$libc_type" = "musl" ]; then
                echo "${sys_type}-musl-arm"
            else
                echo "${sys_type}-arm"
            fi
            ;;
        aarch64)
            if [ "$libc_type" = "musl" ]; then
                echo "${sys_type}-musl-arm64"
            else
                echo "${sys_type}-arm64"
            fi
            ;;
        x86_64)
            if [ "$libc_type" = "musl" ]; then
                echo "${sys_type}-musl-x64"
            else
                echo "${sys_type}-x64"
            fi
            ;;
        *)
            echo "Unknown architecture"
            ;;
    esac
}

install_dependencies() {
    echo "正在检查依赖项：jq、ICU 和 curl"

    local update_needed=false
    local dependencies=("jq" "icu icu-full-data" "curl")
    local commands=("jq" "icu" "curl")

    for i in "${!commands[@]}"; do
        if ! command -v "${commands[$i]}" >/dev/null 2>&1 && ! opkg list-installed | grep -q "${commands[$i]}"; then
            echo "${commands[$i]} 未安装，准备安装..."
            update_needed=true
            break
        else
            echo "${commands[$i]} 已安装，跳过安装步骤。"
        fi
    done

    if [ "$update_needed" = true ]; then
        echo "更新 opkg..."
        opkg update
        for dep in "${dependencies[@]}"; do
            echo "安装 $dep..."
            opkg install $dep
        done
    fi

    echo "依赖项检查和安装完成。"
}

# 函数：列出可用的版本并让用户选择
list_versions() {
    echo "正在获取 .NET SDK 版本信息..."
    # 下载 .NET SDK 的版本信息 JSON
    TEMP_JSON_FILE="/tmp/dotnet_versions.json"
    curl -s https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json -o "$TEMP_JSON_FILE"

    # 获取 .NET SDK 的可用版本列表
    echo "正在解析 .NET SDK 版本信息..."
    AVAILABLE_VERSIONS=$(jq -r '.["releases-index"][] | select(.["support-phase"] != "eol") | "\(.["channel-version"]) (\(.["support-phase"])) - SDK: \(.["latest-sdk"]) Runtime: \(.["latest-runtime"])"' "$TEMP_JSON_FILE")
    VERSION_URLS=$(jq -r '.["releases-index"][] | select(.["support-phase"] != "eol") | .["channel-version"] + " " + .["latest-sdk"] + " " + .["releases.json"]' "$TEMP_JSON_FILE")

    if [ -z "$AVAILABLE_VERSIONS" ]; then
        echo "没有找到可用的 .NET SDK 版本。请检查网络连接或稍后再试。"
        rm "$TEMP_JSON_FILE"
        return
    fi

    echo "可用的 .NET SDK 版本："
    # 使用循环手动为每个版本添加序号并显示
    version_count=1
    echo "$AVAILABLE_VERSIONS" | while IFS= read -r line; do
        echo "$version_count) $line"
        version_count=$((version_count + 1))
    done

    # 提示用户选择一个版本
    read -p "请输入要安装的版本的序号： " version_number

    # 获取用户选择的版本信息
    selected_version=$(echo "$AVAILABLE_VERSIONS" | sed -n "${version_number}p")
    selected_version_url=$(echo "$VERSION_URLS" | sed -n "${version_number}p" | awk '{print $3}')

    # 下载所选版本的 releases.json
    echo "正在获取版本 $selected_version 的 releases.json..."
    releases_json=$(curl -s "$selected_version_url")

    # 获取当前系统架构
    system_arch=$(get_system_architecture)
    echo "当前系统架构： $system_arch"

    # 显示所选版本的可用 SDK
    sdks=$(echo "$releases_json" | jq -r --arg system_arch "$system_arch" '
    .releases[].sdk.files
    | map(select(.rid | contains($system_arch)))
    | .[]
    | "\(.rid): \(.url)"
    ')

    if [ -z "$sdks" ]; then
        echo "版本 $selected_version 没有适合当前系统架构的 SDK 可用。请尝试选择其他版本。"
        rm "$TEMP_JSON_FILE"
        return
    fi

    echo "版本 $selected_version 可用的 SDK："
    echo "$sdks" | awk '{print NR")", $0}'

    # 提示用户选择一个 SDK
    read -p "请输入要安装的 SDK 的序号： " sdk_number

    # 获取所选 SDK 的下载 URL
    selected_sdk=$(echo "$sdks" | sed -n "${sdk_number}p" | awk '{print $2}')
    download_url=$(echo "$sdks" | sed -n "${sdk_number}p" | awk '{print $3}')

    # 获取所选 SDK 的下载 URL
    selected_sdk=$(echo "$sdks" | sed -n "${sdk_number}p")
    sdk_rid=$(echo "$selected_sdk" | awk '{print $1}')
    download_url=$(echo "$selected_sdk" | awk '{print $2}')

    # 提取文件名
    filename=$(basename "$download_url")

    # 下载并安装所选 SDK
    echo "正在从 $download_url 下载 SDK..."
    wget "$download_url" -P /tmp

    # 创建安装目录
    mkdir -p "$INSTALL_PATH"

    # 解压下载的文件
    tar -zxvf "/tmp/$filename" -C "$INSTALL_PATH"

    # 检查并创建 .profile 文件，如果不存在的话
    PROFILE_FILE="$HOME/.profile"
    if [ ! -f "$PROFILE_FILE" ]; then
        touch "$PROFILE_FILE"
    fi

    # 添加环境变量配置到用户的 .profile 文件中，如果不存在的话
    if ! grep -q 'export DOTNET_ROOT="'"$INSTALL_PATH"'"' "$PROFILE_FILE"; then
        echo "export DOTNET_ROOT=\"$INSTALL_PATH\"" >> "$PROFILE_FILE"
    fi

    if ! grep -q 'export PATH="\$DOTNET_ROOT:\$PATH"' "$PROFILE_FILE"; then
        echo "export PATH=\"\$DOTNET_ROOT:\$PATH\"" >> "$PROFILE_FILE"
    fi

    chmod +x "$PROFILE_FILE"
    # 加载新的环境变量配置
    source "$PROFILE_FILE"

    echo "安装完成！"

    # 删除临时文件
    rm "$TEMP_JSON_FILE"
}


# 主菜单
echo "欢迎使用 .NET SDK 安装程序（适用于 OpenWrt）"
echo "----------------------------------------"
echo "1) 安装 .NET SDK"
echo "2) 退出"
read -p "请输入您的选择： " choice

case $choice in
    1) install_dependencies
       list_versions ;;
    2) echo "正在退出..."; exit ;;
    *) echo "无效的选择。正在退出..."; exit ;;
esac

exit 0
