<#
  画布一键升级脚本（老用户专用，双击 .bat 会调用它）

  做的事：
    1. 对比本地版本和 GitHub 上的最新版本
    2. 下载最新安装包到临时目录
    3. 解压后覆盖程序文件，但**保留** config / data / assets / logs / 浏览器登录态
    4. 打印结果，提示重启

  用法（一般由 升级到最新版.bat 调用）：
    powershell -ExecutionPolicy Bypass -File upgrade.ps1 -Dest "D:\豆包画布"
#>

param(
  [string]$Dest = "",
  [string]$Repo = "fff233yfyf/manju-canvas"
)

$ErrorActionPreference = "Stop"
$Raw = "https://raw.githubusercontent.com/$Repo/main"

function Say($msg, $color = "White") {
  Write-Host $msg -ForegroundColor $color
}

if (-not $Dest) {
  $Dest = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not (Test-Path $Dest)) {
  Say "找不到程序目录：$Dest" "Red"
  exit 1
}

Say ""
Say "  画布升级工具" "Cyan"
Say "  ────────────────────────────"

# 本地版本
$localPkg = Join-Path $Dest "package.json"
if (-not (Test-Path $localPkg)) {
  Say "这个文件夹里没有 package.json，可能选错了目录。" "Red"
  Say "把本文件放到「豆包画布」程序目录里再双击。" "Yellow"
  exit 1
}
$localVer = (Get-Content $localPkg -Raw | ConvertFrom-Json).version
Say "  当前版本：$localVer"

# 线上版本
try {
  $upd = Invoke-RestMethod -Uri "$Raw/update.json?t=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())" -TimeoutSec 20
} catch {
  Say "  连不上更新服务器（检查网络）：$($_.Exception.Message)" "Red"
  exit 1
}
Say "  最新版本：$($upd.version)  ($($upd.buildDate))"
if ($upd.notes) { Say "  更新内容：$($upd.notes)" "DarkGray" }

function VerNum($v) { $v -replace "[^0-9\.]", "" }
if ([version](VerNum $upd.version) -le [version](VerNum $localVer)) {
  Say ""
  Say "  已经是最新版，不用升级。" "Green"
  exit 0
}

# 下载
$tmp = Join-Path $env:TEMP ("manju-upgrade-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$zip = Join-Path $tmp "new.zip"
Say ""
Say "  正在下载 $($upd.version) …"
try {
  Invoke-WebRequest -Uri $upd.url -OutFile $zip -TimeoutSec 300
} catch {
  Say "  下载失败：$($_.Exception.Message)" "Red"
  exit 1
}
Say ("  下载完成：{0:N0} KB" -f ((Get-Item $zip).Length / 1KB))

# 解压
Say "  解压中…"
$newDir = Join-Path $tmp "new"
Expand-Archive -LiteralPath $zip -DestinationPath $newDir -Force
$src = $newDir
$top = Get-ChildItem $newDir -Force | Where-Object { $_.Name -notlike "__*" }
if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $src = $top[0].FullName }

# 覆盖（保留用户数据）
Say "  覆盖程序文件（配置、画布、登录态都保留）…"
$xd = @("config", "data", "assets", "logs", "node_modules")
$args = @($src, $Dest, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:1", "/W:1")
foreach ($d in $xd) { $args += "/XD"; $args += (Join-Path $Dest $d) }
$out = & robocopy @args
$code = $LASTEXITCODE
if ($code -ge 8) {
  Say "  覆盖失败（robocopy 返回 $code）" "Red"
  Say "  $out" "DarkGray"
  exit 1
}

# 清理
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Say ""
Say "  ✓ 升级完成：$localVer → $($upd.version)" "Green"
Say ""
Say "  现在请：" "Cyan"
Say "    1. 关掉那个黑窗口（池子的窗口），或者按 Ctrl+C" "White"
Say "    2. 双击 start-all.bat 重新启动" "White"
Say ""
