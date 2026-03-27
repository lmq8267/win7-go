#!/bin/bash
# =========================================
# Go Legacy Win7 安装脚本（跨平台版本）
# 支持: Linux, macOS, Windows (PowerShell / Git Bash / CMD)
# =========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
print_info() { echo -e "${BLUE}[信息]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }
print_step() { echo -e "${PURPLE}[步骤]${NC} $1"; }

# 读取环境变量或默认值
VERSION="${GO_VERSION:-1.25.7-1}"
VERSION_FILE="${GO_VERSION_FILE:-}"
TOKEN="${TOKEN:-}"
ARCH="${ARCHITECTURE:-}"

GITHUB_API="https://api.github.com/repos/thongtech/go-legacy-win7/releases"
BASE_URL="https://github.com/thongtech/go-legacy-win7/releases/download"

# =======================
# 平台和架构检测
# =======================
detect_platform() {
    print_info "检测系统平台和架构..."
    UNAME_OUT="$(uname -s 2>/dev/null || echo Windows_NT)"
    case "$UNAME_OUT" in
        Linux*) OS="linux"; print_info "检测到操作系统: Linux" ;;
        Darwin*) OS="darwin"; print_info "检测到操作系统: macOS" ;;
        CYGWIN*|MINGW*|MSYS*|Windows_NT) OS="windows"; print_info "检测到操作系统: Windows" ;;
        *) print_error "不支持的操作系统: $UNAME_OUT"; exit 1 ;;
    esac

    if [ -n "$ARCH" ]; then
        print_info "使用指定的架构: $ARCH"
        case "$ARCH" in
            x86) ARCH_MAP="386" ;;
            x64) ARCH_MAP="amd64" ;;
            arm64) ARCH_MAP="arm64" ;;
            arm) ARCH_MAP="arm" ;;
            *) print_error "不支持的架构: $ARCH"; exit 1 ;;
        esac
    else
        case "$(uname -m 2>/dev/null || echo x86_64)" in
            x86_64) ARCH_MAP="amd64"; print_info "检测到架构: amd64" ;;
            i386|i686) ARCH_MAP="386"; print_info "检测到架构: 386" ;;
            arm64|aarch64) ARCH_MAP="arm64"; print_info "检测到架构: arm64" ;;
            arm*) ARCH_MAP="arm"; print_info "检测到架构: arm" ;;
            *) print_error "不支持的架构: $(uname -m)"; exit 1 ;;
        esac
    fi
    print_success "平台检测完成: ${OS}_${ARCH_MAP}"
}

# =======================
# 从文件读取版本
# =======================
read_version_from_file() {
    if [ -n "$VERSION_FILE" ] && [ -f "$VERSION_FILE" ]; then
        print_info "从文件读取版本: $VERSION_FILE"
        if [[ "$VERSION_FILE" == *"go.mod"* ]]; then
            VERSION=$(grep -o 'go [0-9]\+\.[0-9]\+\.[0-9]\+' "$VERSION_FILE" | cut -d' ' -f2)
        elif [[ "$VERSION_FILE" == *".go-version"* ]]; then
            VERSION=$(cat "$VERSION_FILE" | tr -d '\n\r')
        elif [[ "$VERSION_FILE" == *".tool-versions"* ]]; then
            VERSION=$(grep "^go " "$VERSION_FILE" | cut -d' ' -f2)
        fi
        if [ -n "$VERSION" ]; then print_success "从文件读取到版本: $VERSION"; else print_warning "无法从文件读取版本，使用默认版本"; fi
    fi
}

# =======================
# 获取版本并匹配文件
# =======================
get_latest_versions_and_file() {
    print_info "获取版本信息..."
  
    CLEAN_VERSION="${VERSION#v}"  # 去掉用户输入的 v 前缀
    AUTH_HEADER=""
    if [ -n "$TOKEN" ]; then
        AUTH_HEADER="-H \"Authorization: token $TOKEN\""
    fi
  
    # 获取所有 releases JSON
    if command -v curl >/dev/null 2>&1; then
        RELEASE_JSON=$(eval curl -s $AUTH_HEADER "https://api.github.com/repos/thongtech/go-legacy-win7/releases")
    elif command -v wget >/dev/null 2>&1; then
        if [ -n "$TOKEN" ]; then
            RELEASE_JSON=$(wget -q --header="Authorization: token $TOKEN" -O - "https://api.github.com/repos/thongtech/go-legacy-win7/releases")
        else
            RELEASE_JSON=$(wget -q -O - "https://api.github.com/repos/thongtech/go-legacy-win7/releases")
        fi
    else
        print_error "需要 curl 或 wget 来获取版本信息"
        exit 1
    fi
    
    if [ -z "$RELEASE_JSON" ]; then
        print_warning "无法获取在线版本信息，使用输入版本"
        RESOLVED_VERSION="$VERSION"
        return
    fi
  
    # 查找匹配指定版本的最新 release
    if command -v jq >/dev/null 2>&1; then
        # 提取所有匹配版本的 tag，按版本排序，取最新的
        MATCHING_VERSIONS=$(echo "$RELEASE_JSON" | jq -r ".[] | select(.tag_name | test(\"^v?${CLEAN_VERSION}(-[0-9]+)?$\")) | .tag_name" | sort -V | tail -1)
        
        if [ -n "$MATCHING_VERSIONS" ]; then
            # 获取匹配版本的完整 release 信息
            MATCHING_RELEASE=$(echo "$RELEASE_JSON" | jq ".[] | select(.tag_name == \"$MATCHING_VERSIONS\")")
            RESOLVED_VERSION="${MATCHING_VERSIONS#v}"
            print_success "找到匹配版本: $RESOLVED_VERSION"
        else
            print_warning "未找到匹配版本 ${CLEAN_VERSION}，使用默认版本"
            RESOLVED_VERSION="$VERSION"
            MATCHING_RELEASE=$(echo "$RELEASE_JSON" | jq ".[] | select(.tag_name == \"v$VERSION\")")
        fi
    else
        print_warning "未安装 jq，回退使用基础版本: $VERSION"
        RESOLVED_VERSION="$VERSION"
        MATCHING_RELEASE=$(echo "$RELEASE_JSON" | jq ".[] | select(.tag_name == \"v$VERSION\")")
    fi
  
    # 匹配 assets 文件
    FILE_URL=$(echo "$MATCHING_RELEASE" | jq -r '.assets[].browser_download_url' | grep "${OS}_${ARCH_MAP}" | head -n1)
    if [ -z "$FILE_URL" ]; then
        print_error "未找到匹配 ${OS}_${ARCH_MAP} 的下载文件"
        exit 1
    fi
    DOWNLOAD_URL="$FILE_URL"
    FILE_BASENAME=$(basename "$DOWNLOAD_URL")
    if [[ "$FILE_BASENAME" == *.zip ]]; then EXT="zip"; else EXT="tar.gz"; fi
    FILENAME="$FILE_BASENAME"
  
    print_info "文件名: $FILENAME"
    print_info "下载链接: $DOWNLOAD_URL"
}

# =======================
# 下载文件
# =======================
download_file() {
    print_step "开始下载文件"
    if [ -f "$FILENAME" ]; then rm -f "$FILENAME"; fi
    if command -v curl >/dev/null 2>&1; then
        print_info "使用 curl 下载文件..."
        curl -L --progress-bar -o "${FILENAME}" "${DOWNLOAD_URL}"
    elif command -v wget >/dev/null 2>&1; then
        print_info "使用 wget 下载文件..."
        wget --progress=bar:force -O "${FILENAME}" "${DOWNLOAD_URL}"
    else
        print_error "需要 curl 或 wget 来下载文件"
        exit 1
    fi
    if [ ! -f "${FILENAME}" ]; then print_error "文件下载失败"; exit 1; fi
    print_success "文件下载完成"
}

# =======================
# 安装 Go
# =======================
install_go() {
    print_step "开始安装 Go"
    INSTALL_DIR="$HOME/go-legacy-win7"
    print_info "安装目录: ${INSTALL_DIR}"
    if [ -d "${INSTALL_DIR}" ]; then print_info "清理旧安装目录..."; rm -rf "${INSTALL_DIR}"; fi
    mkdir -p "${INSTALL_DIR}"

    # 解压文件
    print_info "解压文件..."
    if [ "$EXT" = "zip" ]; then
        if command -v unzip >/dev/null 2>&1; then
            unzip -q "${FILENAME}" -d "${INSTALL_DIR}"
        elif command -v tar >/dev/null 2>&1; then
            tar -xf "${FILENAME}" -C "${INSTALL_DIR}"
        else
            print_error "需要 unzip 或 tar 来解压 zip 文件"
            exit 1
        fi
    else
        if command -v tar >/dev/null 2>&1; then
            tar -xzf "${FILENAME}" -C "${INSTALL_DIR}"
        else
            print_error "需要 tar 来解压 tar.gz 文件"
            exit 1
        fi
    fi

    # 查找 bin 目录
    GO_BIN_DIR=""
    if [ -d "${INSTALL_DIR}/go/bin" ]; then
        GO_BIN_DIR="${INSTALL_DIR}/go/bin"
        GOROOT_PATH="${INSTALL_DIR}/go"
    elif [ -d "${INSTALL_DIR}/bin" ]; then
        GO_BIN_DIR="${INSTALL_DIR}/bin"
        GOROOT_PATH="${INSTALL_DIR}"
    elif [ -d "${INSTALL_DIR}/go-legacy-win7/bin" ]; then
        GO_BIN_DIR="${INSTALL_DIR}/go-legacy-win7/bin"
        GOROOT_PATH="${INSTALL_DIR}/go-legacy-win7"
    else
        print_error "找不到 go 二进制文件目录"
        exit 1
    fi
    print_success "文件解压完成"

    # 设置环境变量
    print_step "设置环境变量"

    # 当前会话立即生效
    export PATH="${GO_BIN_DIR}:$PATH"
    export GOROOT="${GOROOT_PATH}"
    export GOTOOLCHAIN=local
    [ -z "$ARCH" ] || export ARCH="${ARCH}"

    # GitHub Actions 环境变量
    if [ -n "$GITHUB_PATH" ]; then
        if [ "$OS" = "windows" ]; then
            # Windows 需要转换路径格式，使用 cygpath -w 优先
            WIN_GO_BIN_DIR=$(cygpath -w "$GO_BIN_DIR" 2>/dev/null || echo "$GO_BIN_DIR" | sed 's|^/\([a-zA-Z]\)/|\1:\\|;s|/|\\|g')
            echo "${WIN_GO_BIN_DIR}" >> "$GITHUB_PATH"
        else
            echo "${GO_BIN_DIR}" >> "$GITHUB_PATH"
        fi
        print_info "已添加路径到 GitHub Actions PATH"
    fi  
    if [ -n "$GITHUB_ENV" ]; then
        # Windows 环境下转换 GOROOT 路径格式
        if [ "$OS" = "windows" ]; then
            WIN_GOROOT=$(cygpath -w "$GOROOT_PATH" 2>/dev/null || echo "$GOROOT_PATH" | sed 's|^/\([a-zA-Z]\)/|\1:\\|;s|/|\\|g')
            echo "GOROOT=${WIN_GOROOT}" >> "$GITHUB_ENV"
        else
            echo "GOROOT=${GOROOT_PATH}" >> "$GITHUB_ENV"
        fi
        echo "GOTOOLCHAIN=local" >> "$GITHUB_ENV"
        [ -z "$ARCH" ] || echo "ARCH=${ARCH}" >> "$GITHUB_ENV"
        print_info "已设置 GitHub Actions 环境变量"
    fi

    # Linux / macOS 本地环境变量
    if [ "$OS" != "windows" ]; then
        echo "export PATH=\"${GO_BIN_DIR}:\$PATH\"" >> ~/.bashrc
        echo "export GOROOT=\"${GOROOT_PATH}\"" >> ~/.bashrc
        echo "export GOTOOLCHAIN=local" >> ~/.bashrc
        [ -z "$ARCH" ] || echo "export ARCH=\"${ARCH}\"" >> ~/.bashrc
        print_info "已设置本地环境变量到 ~/.bashrc"
    fi

    # Windows 永久生效（用户级环境变量）
    if [ "$OS" = "windows" ]; then
        # 转换为 Windows 路径格式
        WIN_GO_BIN_DIR=$(echo "$GO_BIN_DIR" | sed 's|/c/|C:\\|;s|/|\\|g')
        WIN_GOROOT=$(echo "$GOROOT_PATH" | sed 's|/c/|C:\\|;s|/|\\|g')

        powershell -Command "$oldPath=[Environment]::GetEnvironmentVariable('PATH','User'); if(-not $oldPath){$oldPath=''}; $cleanPath=($oldPath -split ';' | Where-Object {$_ -notmatch 'hostedtoolcache.*go'}) -join ';'; if($cleanPath -notlike '*${WIN_GO_BIN_DIR}*'){[Environment]::SetEnvironmentVariable('PATH','${WIN_GO_BIN_DIR};'+$cleanPath,'User')}; [Environment]::SetEnvironmentVariable('GOROOT','${WIN_GOROOT}','User'); [Environment]::SetEnvironmentVariable('GOTOOLCHAIN','local','User')" 2>/dev/null || true

        if [ -n "$ARCH" ]; then
            powershell -Command "[Environment]::SetEnvironmentVariable('ARCH','${ARCH}','User')" 2>/dev/null || true
        fi
        print_info "Windows 用户环境变量已永久生效，新开的终端将可直接使用 go"
    fi

    # 验证安装
    print_step "验证安装"
    if command -v go >/dev/null 2>&1; then
        GO_VERSION_OUTPUT=$(go version)
        print_success "Go 安装成功!"
        print_info "版本信息: $GO_VERSION_OUTPUT"
    else
        print_error "Go 安装验证失败"
        exit 1
    fi
}

# =======================
# 清理和总结
# =======================
cleanup_and_summary() {
    print_step "清理临时文件"
    rm -f "${FILENAME}"
    print_success "Go Legacy Win7 安装完成!"
    echo -e "${CYAN}=== 安装摘要 ===${NC}"
    echo -e "版本: ${GREEN}${RESOLVED_VERSION}${NC}"
    echo -e "平台: ${GREEN}${OS}_${ARCH_MAP}${NC}"
    echo -e "安装目录: ${GREEN}${INSTALL_DIR}${NC}"
    echo -e "GOROOT: ${GREEN}${GOROOT_PATH}${NC}"
    echo -e "Go Bin 目录: ${GREEN}${GO_BIN_DIR}${NC}"
    echo -e "${YELLOW}系统环境变量已添加到 ~/.bashrc${NC}"
    if [ -n "$GITHUB_ENV" ]; then echo -e "${YELLOW}GitHub Actions 环境变量已设置${NC}"; fi
}

# =======================
# 主函数
# =======================
main() {
    echo -e "${CYAN}"
    echo "======================================================="
    echo "   Go Legacy Win7 安装脚本 （构建的程序可在win7运行）"
    echo "======================================================="
    echo -e "${NC}"
    detect_platform
    read_version_from_file
    get_latest_versions_and_file
    download_file
    install_go
    cleanup_and_summary
}

# 运行
main
