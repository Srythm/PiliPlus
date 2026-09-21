# build-apk.ps1 — PiliPlus release APK build helper
#
# 用法: 在仓库根目录 powershell 中执行
#   .\build-apk.ps1
#
# 行为:
#   - 自动读取 git HEAD commit hash
#   - 自动注入当前 unix 时间戳
#   - 自动读 pubspec.yaml 的 version (semver 3 段) 取 versionCode
#   - 通过 --dart-define 把 4 个值注入 BuildConfig:
#       pili.code  -> Android versionCode
#       pili.name  -> Android versionName (About 显示)
#       pili.time  -> BuildConfig.buildTime (检查更新比较)
#       pili.hash  -> BuildConfig.commitHash (About 显示)
#   - flutter build apk --release
#
# 环境配置:
#   本机构建环境不硬编码在本文件里。请复制 build.local.ps1.example 为
#   build.local.ps1 (已被 .gitignore 忽略) 并按本机情况填写;
#   也可直接通过环境变量提供:
#     PILI_JAVA_HOME / JAVA_HOME
#     PILI_ANDROID_HOME / ANDROID_HOME / ANDROID_SDK_ROOT
#     PILI_HTTP_PROXY        例如 Clash 默认的 7890 端口,直连可不设
#     PILI_FLUTTER_BIN       flutter 可执行文件绝对路径(可选)
#     PILI_FVM_ROOT          fvm 根目录(可选,默认 ~/fvm)
#
# 依赖:
#   - fvm + 与 .fvmrc 一致的 Flutter 版本在 PATH 中,或设 PILI_FLUTTER_BIN
#   - JDK 17+
#   - Android SDK platform-tools / build-tools 已装
#   - 大陆用户需要可达的 HTTP(S) 代理
#   - pubspec.yaml 中 version: X.Y.Z+N (3 段 semver)

$ErrorActionPreference = "Stop"

# ============ 载入本机配置 ============
$repoRoot = Get-Location
$localConfig = Join-Path $repoRoot "build.local.ps1"
$configSource = "环境变量"
if (Test-Path $localConfig) {
    . $localConfig
    $configSource = "build.local.ps1"
}

function Resolve-Env {
    param(
        [string[]] $Names,
        [string] $Hint,
        [switch] $Optional,
        [string] $Default
    )
    foreach ($n in $Names) {
        $v = [Environment]::GetEnvironmentVariable($n)
        if ($v) { return $v }
    }
    if ($Optional) { return $Default }
    Write-Error "缺少环境配置: $($Names -join ' / ')。$Hint"
    exit 1
}

$javaHome = Resolve-Env -Names @("PILI_JAVA_HOME", "JAVA_HOME") `
    -Hint "请在 build.local.ps1 里设置,或设置同名环境变量。"
$androidHome = Resolve-Env -Names @("PILI_ANDROID_HOME", "ANDROID_HOME", "ANDROID_SDK_ROOT") `
    -Hint "请在 build.local.ps1 里设置,或设置同名环境变量。"
$proxy = Resolve-Env -Names @("PILI_HTTP_PROXY", "HTTP_PROXY", "HTTPS_PROXY") `
    -Hint "直连可用时可不设。" `
    -Optional -Default ""

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome
if ($proxy) {
    $env:HTTP_PROXY = $proxy
    $env:HTTPS_PROXY = $proxy
}
$env:Path = "$javaHome\bin;$env:Path"

Write-Host "配置来源:     $configSource"
Write-Host "JAVA_HOME:    $javaHome"
Write-Host "ANDROID_HOME: $androidHome"
if ($proxy) { Write-Host "PROXY:        $proxy" } else { Write-Host "PROXY:        (未设置,直连)" }

# ============ 校验仓库 ============
if (-not (Test-Path "$repoRoot\pubspec.yaml")) {
    Write-Error "请在 PiliPlus 仓库根目录下运行"
    exit 1
}

# ============ 读 pubspec version ============
$psLine = Select-String -Path "$repoRoot\pubspec.yaml" -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $psLine) {
    Write-Error "pubspec.yaml 找不到 version 行"
    exit 1
}
$pubVer = $psLine.Matches[0].Groups[1].Value   # 例如 "2.0.9+2"
Write-Host "pubspec version: $pubVer"

# semver 3 段: "X.Y.Z+BUILD"
$semverRegex = '^(\d+)\.(\d+)\.(\d+)\+(\d+)$'
if ($pubVer -notmatch $semverRegex) {
    Write-Error "pubspec version '$pubVer' 不符合 semver 3 段 (X.Y.Z+BUILD)。Flutter 严格 3 段,4 段会 pub get 报错"
    exit 1
}
$PUB_NAME = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
$BUILD_CODE = [int]$Matches[4]

# ============ git ============
git rev-parse --is-inside-work-tree 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "不是 git 仓库"
    exit 1
}
$COMMIT_HASH = (git rev-parse --short HEAD).Trim()
$BRANCH = (git rev-parse --abbrev-ref HEAD).Trim()
Write-Host "git branch: $BRANCH"
Write-Host "commit:    $COMMIT_HASH"

# ============ 注入变量 ============
$BUILD_TIME = [int][double]::Parse((Get-Date -UFormat %s))
$VERSION_NAME = $PUB_NAME

Write-Host "=========================="
Write-Host "pili.code  = $BUILD_CODE"
Write-Host "pili.name  = $VERSION_NAME"
Write-Host "pili.time  = $BUILD_TIME"
Write-Host "pili.hash  = $COMMIT_HASH"
Write-Host "=========================="

# ============ 选 Flutter binary ============
# 优先级: PILI_FLUTTER_BIN > fvm (按 .fvmrc) > PATH 中的 flutter
$flutterBin = Resolve-Env -Names @("PILI_FLUTTER_BIN") -Optional -Default $null
if (-not $flutterBin -and (Get-Command fvm -ErrorAction SilentlyContinue)) {
    $fvmVersion = Select-String -Path "$repoRoot\.fvmrc" -Pattern '"flutter":\s*"([^"]+)"' | Select-Object -First 1
    if ($fvmVersion) {
        $v = $fvmVersion.Matches[0].Groups[1].Value
        $fvmRoot = Resolve-Env -Names @("PILI_FVM_ROOT", "FVM_CACHE_PATH") -Optional -Default "$env:USERPROFILE\fvm"
        $candidate = Join-Path $fvmRoot "versions\$v\bin\flutter.bat"
        if (Test-Path $candidate) { $flutterBin = $candidate }
    }
}
if (-not $flutterBin) {
    $flutterBin = (Get-Command flutter -ErrorAction SilentlyContinue).Source
}
if (-not $flutterBin) {
    Write-Error "找不到 flutter binary (PILI_FLUTTER_BIN / fvm / PATH 均未命中)"
    exit 1
}
Write-Host "flutter:      $flutterBin"

# ============ build ============
# 记录构建前的产物指纹，用于事后识别「陈旧 APK 被误报为成功」(2026-09-21)
$apkPath = "$repoRoot\build\app\outputs\flutter-apk\app-release.apk"
$apkStampBefore = if (Test-Path $apkPath) { (Get-Item $apkPath).LastWriteTimeUtc } else { $null }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$args = @(
    "build", "apk", "--release"
    "--dart-define=pili.code=$BUILD_CODE"
    "--dart-define=pili.name=$VERSION_NAME"
    "--dart-define=pili.time=$BUILD_TIME"
    "--dart-define=pili.hash=$COMMIT_HASH"
)
& $flutterBin @args
$buildExit = $LASTEXITCODE
$sw.Stop()
Write-Host ("build done in {0:N0}s" -f $sw.Elapsed.TotalSeconds)

# ---- 闸门 1：构建失败则立即中止，不去「验证」任何东西 ----
if ($buildExit -ne 0) {
    Write-Host ""
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    Write-Host "构建失败（flutter 退出码 $buildExit）。"
    Write-Host "已跳过产物验证 —— 不要误把上一次留下的旧 APK 当成本次结果。"
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit $buildExit
}

# ============ 验证 ============
$apk = $apkPath
if (-not (Test-Path $apk)) {
    Write-Host "!!! 构建报成功但找不到产物: $apk"
    exit 3
}
# ---- 闸门 2：产物必须是本次新生成的，否则拒绝通过 ----
if ($null -ne $apkStampBefore -and (Get-Item $apk).LastWriteTimeUtc -le $apkStampBefore) {
    Write-Host "!!! 产物时间戳早于本次构建开始 —— 这是陈旧 APK，不能作为本次结果"
    Write-Host "    产物: $apk"
    Write-Host "    时间: $((Get-Item $apk).LastWriteTimeUtc) (构建前为 $apkStampBefore)"
    exit 3
}
if (Test-Path $apk) {
    $buildTools = Get-ChildItem -Path "$androidHome\build-tools" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($buildTools) {
        $aapt = Join-Path $buildTools.FullName "aapt2.exe"
        if (Test-Path $aapt) {
            Write-Host "=== aapt2 badging ==="
            & $aapt dump badging $apk 2>&1 | Select-String -Pattern 'package:|application-label' | ForEach-Object { Write-Host $_ }
        }
    }
    Write-Host "APK SHA1: $((Get-Content "$apk.sha1").Trim())"
}
