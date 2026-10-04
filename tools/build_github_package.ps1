[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Commit,
    [string]$ExportDirectory = "build\windows",
    [string]$ExecutableName = "warseed-debug.exe",
    [string]$OutputDirectory = "build\github-packages"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,59}$') { throw "Invalid package version." }
if ($Commit -notmatch '^[a-fA-F0-9]{40}$') { throw "Commit must be the full Git SHA." }
if ($ExecutableName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$') { throw "Invalid executable name." }
$repositoryRoot = Split-Path $PSScriptRoot -Parent
function Resolve-RepositoryPath([string]$Value) {
    if ([IO.Path]::IsPathRooted($Value)) { return [IO.Path]::GetFullPath($Value) }
    return [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Value))
}
$exportRoot = Resolve-RepositoryPath $ExportDirectory
$outputRoot = Resolve-RepositoryPath $OutputDirectory
$packageName = "WARSEED-$Version-Windows-x64"
$packageRoot = Join-Path $outputRoot $packageName
$archivePath = Join-Path $outputRoot "$packageName.zip"
$checksumPath = "$archivePath.sha256"
foreach ($path in @($packageRoot, $archivePath, $checksumPath)) {
    if (Test-Path -LiteralPath $path) { throw "Package output already exists: $path" }
}
$sourceExe = Join-Path $exportRoot $ExecutableName
$sourcePck = [IO.Path]::ChangeExtension($sourceExe, '.pck')
$runtime = Join-Path $exportRoot 'data_WARSEED_windows_x86_64'
foreach ($path in @($sourceExe, $sourcePck,
    (Join-Path $runtime 'WARSEED.dll'), (Join-Path $runtime 'GodotSharp.dll'),
    (Join-Path $runtime 'WARSEED.runtimeconfig.json'))) {
    if (-not [IO.File]::Exists($path)) { throw "Required Mono export file not found: $path" }
}
[IO.Directory]::CreateDirectory($packageRoot) | Out-Null
Copy-Item -LiteralPath $sourceExe -Destination (Join-Path $packageRoot 'WARSEED.exe')
Copy-Item -LiteralPath $sourcePck -Destination (Join-Path $packageRoot 'WARSEED.pck')
Copy-Item -LiteralPath $runtime -Destination $packageRoot -Recurse
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'docs\CURRENT_GAMEPLAY.md') -Destination (Join-Path $packageRoot 'CURRENT_GAMEPLAY.md')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'docs\PLAYER_AI_CONTROL_CONTRACT_20261004.md') -Destination (Join-Path $packageRoot 'PLAYER_AI_CONTROL_CONTRACT.md')
$utf8 = [Text.UTF8Encoding]::new($false)
$projectVersion = (Select-String -LiteralPath (Join-Path $repositoryRoot 'project.godot') -Pattern '^config/version="([^"]+)"$').Matches[0].Groups[1].Value
$metadata = [ordered]@{
    schema_version = 1; version = $Version; source_commit = $Commit.ToLowerInvariant()
    project_version = $projectVersion; godot_version = '4.6.3.stable.mono'
    platform = 'windows-x86_64'; configuration = 'debug'; channel = 'playtest'
    created_utc = [DateTimeOffset]::UtcNow.ToString('o')
    scenario_ids = @('final_decision', 'grey_ridge', 'broken_bridge', 'fog_forest', 'black_well')
    evidence = 'SIMULATED'; HUMAN = 'NOT_RUN'; FPS = 'NOT_RUN'; performance_policy = 'D-028 DEFERRED'
}
[IO.File]::WriteAllText((Join-Path $packageRoot 'BUILD_INFO.json'), ($metadata | ConvertTo-Json -Depth 8), $utf8)
$readme = @"
# WARSEED Windows 测试包 $Version

请解压整个目录，保持 WARSEED.exe、WARSEED.pck 和 data_WARSEED_windows_x86_64 一起。
双击 START_WARSEED.cmd 启动隔离试玩；主菜单选择“最终决战”，也可体验四场旧会战。
将领意图持续有效，整卡操作持续接管；取消转坚守，明确交还后恢复 AI。
现行玩法见 CURRENT_GAMEPLAY.md，操纵规则见 PLAYER_AI_CONTROL_CONTRACT.md。

本包是开发测试版本，整体玩法维护仍未完成。构建标识 $Version；源提交 $Commit。
自动验证不代表真人体验或真实帧率结论。BUILD_INFO.json 保留项目版本与构建来源。
"@
[IO.File]::WriteAllText((Join-Path $packageRoot 'README.md'), $readme, $utf8)
$launcher = "@echo off`r`n`"%~dp0WARSEED.exe`" -- --playtest-session=github-$Version`r`nif errorlevel 1 pause`r`n"
[IO.File]::WriteAllText((Join-Path $packageRoot 'START_WARSEED.cmd'), $launcher, [Text.Encoding]::ASCII)
$entries = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
        bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$manifest = [ordered]@{ schema_version = 1; package_name = $packageName; source_commit = $Commit.ToLowerInvariant(); file_count = $entries.Count; files = $entries }
[IO.File]::WriteAllText((Join-Path $packageRoot 'MANIFEST.json'), ($manifest | ConvertTo-Json -Depth 8), $utf8)
Compress-Archive -LiteralPath $packageRoot -DestinationPath $archivePath -CompressionLevel Optimal
$digest = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($checksumPath, "$digest  $packageName.zip`n", [Text.Encoding]::ASCII)
[pscustomobject]@{ ArchivePath = $archivePath; ChecksumPath = $checksumPath; SHA256 = $digest; PackageDirectory = $packageRoot; FileCount = $entries.Count }
