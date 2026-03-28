# [Go Legacy Win7](https://github.com/thongtech/go-legacy-win7) 安装脚本

一个跨平台的 [Go Legacy Win7](https://github.com/thongtech/go-legacy-win7) 安装脚本，支持构建可在 Windows 7 运行的 Go 程序。

## 功能特性

- **🌍 跨平台支持**：Linux、macOS、Windows (PowerShell / Git Bash / CMD)
- **📦 自动检测**：智能检测流程内的系统平台和架构
- **🔄 版本管理**：支持从文件读取版本或手动指定
- **🚀 一键安装**：自动下载、解压、配置环境变量
- **⚙️ GitHub Actions**：提供完整的 Action 支持

## GitHub Actions 使用示例：

```
- name: 设置 Go Legacy Win7
  uses: lmq8267/win7-go@main
  with:
    go-version: '1.25.7-1'
```

## 输入参数

| 参数 | 描述 | 默认值 | 必需 |
|------|------|------|------|
| `go-version` | 指定要安装的 Go 版本 | `1.25.7-1` | 否 |
| `go-version-file` | 版本文件路径 (go.mod/.go-version/.tool-versions) | | 否 |
| `token` | GitHub API 认证令牌，用于获取[Go Legacy Win7](https://github.com/thongtech/go-legacy-win7)的版本，防止速率限制，一般无需提供 | | 否 |
| `architecture` | 目标架构 (x86/x64/arm64/arm) | 自动检测 | 否 |

## 支持的版本文件

脚本支持从以下文件读取 Go 版本：

- **go.mod**：从 `go 1.x.x` 指令读取
- **.go-version**：直接读取版本号
- **.tool-versions**：从 `go 1.x.x` 行读取

## 环境变量配置

脚本会自动配置以下环境变量：

- **PATH**：添加 Go 二进制文件路径
- **GOROOT**：设置 Go 安装根目录
- **GOTOOLCHAIN**：设置为 `local` 防止自动更新
- **ARCH**：目标架构（如果指定）

## GitHub Actions 环境变量

在 GitHub Actions 中，脚本正确使用：

- **$GITHUB_PATH**：用于 `PATH` 变量（前置追加，不破坏现有路径）
- **$GITHUB_ENV**：用于其他环境变量

## 平台支持

| 操作系统 | 架构 | 支持状态 |
|---------|--------|--------|
| Linux | x86_64, i386, arm64, arm | ✅ |
| macOS | x86_64, arm64 | ✅ |
| Windows | x86_64, i386, arm64, arm | ✅ |

## 安装位置

- **Linux/macOS**：`$HOME/go-legacy-win7`
- **Windows**：`%USERPROFILE%\go-legacy-win7`

## 故障排除

#### 常见问题

1. **找不到 curl 或 wget**

```
# Ubuntu/Debian  
sudo apt-get install curl wget jq  
  
# CentOS/RHEL  
sudo yum install curl wget jq
```

2. **Windows 路径问题**

- 脚本自动使用 `cygpath -w` 转换路径格式
- 确保 `Git` `Bash` 或 `MSYS2` 环境正常

## 验证安装

```
# 检查 Go 版本  
go version  
  
# 检查环境变量  
go env GOROOT  
go env GOTOOLCHAIN
```

## Action 开发

Action 使用 `composite` 类型，主要步骤：

1. 设置 GitHub 工作路径
2. 检测平台和架构
3. 设置版本信息
4. 下载并安装 [Go Legacy Win7](https://github.com/thongtech/go-legacy-win7)
5. 设置输出变量

## 许可证

**MIT License**

## 贡献

欢迎提交 Issue 和 Pull Request！

## 相关链接

[Go 官方文档](https://golang.org/doc)

[GitHub Actions 文档](https://docs.github.com/en/actions)

[go-legacy-win7项目地址](https://github.com/thongtech/go-legacy-win7)

**注意：**

> 此脚本安装的是 `Go Legacy Win7` 增强版本，用于构建可在 Windows 7 上运行的程序。如需标准 Go 版本，可使用[actions/setup-go](https://github.com/actions/setup-go)安装方法。
