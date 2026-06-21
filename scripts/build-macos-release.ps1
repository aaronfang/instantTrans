# 在 Windows / CI 上打包 macOS 发布包
param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dist = Join-Path $Root "dist"
$Name = "instantTrans"

if (-not $Version) {
    $tag = git -C $Root describe --tags --abbrev=0 2>$null
    if ($tag) {
        $Version = $tag.TrimStart("v")
    } else {
        $Version = "0.0.0"
    }
} else {
    $Version = $Version.TrimStart("v")
}

$ReleaseName = "${Name}-macos-${Version}"
$SrcZip = Join-Path $Dist "${ReleaseName}.zip"
$ExtZip = Join-Path $Dist "${ReleaseName}.popclipextz"
$ExtDir = Join-Path $Root "popclip\instantTrans.popclipext"

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue $SrcZip, $ExtZip

Write-Host "==> 打包源码: $SrcZip"
Push-Location $Root
git archive --format=zip "--prefix=${ReleaseName}/" -o $SrcZip HEAD
Pop-Location

Write-Host "==> 打包 PopClip 扩展: $ExtZip"
$TempExt = Join-Path $env:TEMP "instantTrans-ext-$([guid]::NewGuid().ToString())"
New-Item -ItemType Directory -Force -Path $TempExt | Out-Null
Copy-Item -Recurse -Force $ExtDir (Join-Path $TempExt "instantTrans.popclipext")
$ExtZipTemp = Join-Path $Dist "${ReleaseName}.popclipextz.zip"
Compress-Archive -Path (Join-Path $TempExt "instantTrans.popclipext") -DestinationPath $ExtZipTemp -Force
Move-Item -Force $ExtZipTemp $ExtZip
Remove-Item -Recurse -Force $TempExt

Write-Host ""
Write-Host "macOS 发布包已生成:"
Write-Host "  源码包:       $SrcZip"
Write-Host "  PopClip 扩展: $ExtZip"
Write-Host ""
Write-Host "在 macOS 上安装:"
Write-Host "  1. 解压 ${ReleaseName}.zip"
Write-Host "  2. cd ${ReleaseName}"
Write-Host "  3. chmod +x install-mac.sh && ./install-mac.sh"
