#Requires -Version 5.1
<#
.SYNOPSIS
    Windows に残った ZMK キーボードのゴースト（Status=Unknown）エントリを掃除する。

.DESCRIPTION
    対象は USB VID_1D50（ZMK 既定のベンダー ID 1D50）の PnP エントリ。
    PID は 615E / 6160 など複数世代（cormoran / standard ZMK 等）をまとめて扱う。

      既定          : レポートのみ。管理者権限は不要。
      -Apply        : Status が Unknown / Error のエントリを pnputil /remove-device で削除。
                      （Error = Code 10 になった Composite Device もゴーストとして削除する）
                      昇格した PowerShell が必要。
      -IncludeBle   : HKLM\SYSTEM\CurrentControlSet\Enum\BTHLE\DEV_* も調査する。
                      -Apply と併用時は .reg にバックアップしてから削除を試みる。
                      Enum 配下は SYSTEM 所有のため管理者でも失敗することがあり、
                      その場合は PsExec 用のヘルパー .bat をバックアップ先に生成する。

.PARAMETER Apply
    実際に削除する。指定しない場合はレポートのみ。

.PARAMETER IncludeBle
    Bluetooth LE の列挙キーも対象にする（管理者権限を推奨）。

.PARAMETER StableOnly
    指定すると削除対象を ForwardSkip の無い製品（未使用）に限定する。

.EXAMPLE
    .\zmk_device_cleanup.ps1
    .\zmk_device_cleanup.ps1 -IncludeBle
    .\zmk_device_cleanup.ps1 -Apply
    .\zmk_device_cleanup.ps1 -Apply -IncludeBle

.NOTES
    - キーボードの USB ケーブルを抜いた状態で実行する（接続中は Status=OK でスキップされる）。
    - pnputil /remove-device は Windows 10 1809 以降。
    - 1D50:615E は ZMK の既定 VID/PID。同じ VID/PID の別キーボードも対象になる点に注意。
    - 同梱の zmk_device_cleanup.bat から呼ぶと昇格を自動化できる。
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$IncludeBle,
    [switch]$StableOnly
)

$ErrorActionPreference = 'Continue'

# 日本語が cp932 コンソールで化けないように UTF-8 で出力する
try { [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001) } catch { }

# ------------------------------------------------------------------
# ログ出力: .ps1 と同じフォルダ (= バッチファイルと同じ場所) に保存する
# ------------------------------------------------------------------
$LogDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($LogDir)) { $LogDir = (Get-Location).Path }
$LogStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogPath  = Join-Path $LogDir ('zmk_device_cleanup_{0}.log' -f $LogStamp)

try {
    Start-Transcript -LiteralPath $LogPath -Force -ErrorAction Stop | Out-Null
    Write-Host ("ログ: {0}" -f $LogPath) -ForegroundColor DarkGray
}
catch {
    Write-Warning ("ログファイルを開けませんでした: {0} ({1})" -f $LogPath, $_.Exception.Message)
}

# exit してもトランスクリプトが閉じられるようにする
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
} | Out-Null

# VID_1D50 全体を対象にする（615E / 6160 / その他 ZMK 系の複数 PID を拾う）
$VidPattern = 'VID_1D50'
$BleRoot    = 'HKLM:\SYSTEM\CurrentControlSet\Enum\BTHLE'
$ExitCode   = 0

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Section {
    param(
        [Parameter(Mandatory)][string]$Text,
        [string]$Color = 'Cyan'
    )
    Write-Host ''
    Write-Host ("== {0} ==" -f $Text) -ForegroundColor $Color
}

# Properties サブキーが SYSTEM 所有で管理者でも消せない場合に使うヘルパーを生成する。
# %~dp0 を使うので、日本語やスペースを含むパスでも .bat 内に実パスを書かずに済む。
function New-SystemDeleteHelper {
    param(
        [Parameter(Mandatory)][object[]]$Keys,
        [Parameter(Mandatory)][string]$BackupDir
    )

    $systemBat  = Join-Path $BackupDir 'system_delete.bat'
    $wrapperBat = Join-Path $BackupDir 'run_as_system_psexec.bat'

    $lines = @(
        '@echo off',
        'setlocal',
        'rem Delete BTHLE ghost keys as SYSTEM. Run through run_as_system_psexec.bat.',
        'rem Paths are plain HKLM registry paths, so ASCII-only content is safe.'
    )
    foreach ($k in $Keys) {
        $regPath = $k.Name -replace '^HKEY_LOCAL_MACHINE', 'HKLM'
        $lines += ('reg.exe delete "{0}" /f' -f $regPath)
    }
    $lines += 'echo done.'
    $lines += 'pause'
    Set-Content -LiteralPath $systemBat -Value $lines -Encoding Ascii

    $lines = @(
        '@echo off',
        'setlocal',
        'set "HERE=%~dp0"',
        'if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"',
        'set "PSEXEC=%HERE%\PsExec.exe"',
        'if not exist "%PSEXEC%" set "PSEXEC=%HERE%\..\tools\PsExec.exe"',
        'if not exist "%PSEXEC%" (',
        '    echo [ERROR] PsExec.exe not found.',
        '    echo         Put PsExec.exe in this folder, or in ..\tools\',
        '    echo         Download: https://learn.microsoft.com/sysinternals/downloads/psexec',
        '    pause',
        '    exit /b 1',
        ')',
        'echo Deleting ghost keys as SYSTEM ...',
        '"%PSEXEC%" -accepteula -w "%HERE%" -i -s -d cmd.exe /c "%HERE%\system_delete.bat"',
        'echo Started. Reboot the PC after the delete window finishes.',
        'pause'
    )
    Set-Content -LiteralPath $wrapperBat -Value $lines -Encoding Ascii

    return $wrapperBat
}

$isAdmin = Test-IsAdmin

Write-Host '== ZMK device cleanup ==' -ForegroundColor Cyan
Write-Host ("PowerShell : {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
Write-Host ("Elevated   : {0}" -f $isAdmin)
Write-Host ("Target     : {0}" -f $VidPattern)

# --- 1) PnP エントリのレポート -------------------------------------------
Write-Section 'PnP エントリ (USB / HID)'

$devices = @()
try {
    $devices = @(Get-PnpDevice -ErrorAction Stop | Where-Object { $_.InstanceId -match $VidPattern })
}
catch {
    Write-Warning ("Get-PnpDevice に失敗しました: {0}" -f $_.Exception.Message)
    $ExitCode = 3
}

Write-Host ("件数: {0}" -f $devices.Count)
foreach ($group in ($devices | Group-Object Status | Sort-Object Name)) {
    Write-Host ("  Status '{0}': {1}" -f $group.Name, $group.Count)
}

if ($devices.Count -gt 0) {
    Write-Host '一覧:'
    foreach ($d in ($devices | Sort-Object Status, InstanceId)) {
        Write-Host ("  [{0,-9}] {1,-9} {2}" -f $d.Status, $d.Class, $d.InstanceId)
    }
}

# --- 2) 削除 (USB / HID) -------------------------------------------------
if ($Apply) {
    Write-Section '削除 (Status=Unknown / Error のみ)' 'Yellow'

    if (-not $isAdmin) {
        Write-Warning '削除には管理者権限が必要です。'
        Write-Host ("  昇格して再実行: powershell -ExecutionPolicy Bypass -File `"{0}`" -Apply" -f $PSCommandPath)
        Write-Host '  同梱の zmk_device_cleanup.bat に apply を付けると自動で昇格します。'
        try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
        exit 1
    }

    $pnputil = Get-Command pnputil.exe -ErrorAction SilentlyContinue
    if (-not $pnputil) {
        Write-Warning 'pnputil.exe が見つかりません（Windows 10 1809 以降が必要）。'
        try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
        exit 3
    }

    $removed = 0
    $failed  = 0

    foreach ($d in ($devices | Sort-Object InstanceId)) {
        # 削除対象: Unknown(ゴースト) と Error(Code 10 になった個体)
        # 接続中のデバイス(OK)のみスキップする
        if ($d.Status -eq 'OK') {
            Write-Host ("  SKIP (接続中): {0}" -f $d.InstanceId)
            continue
        }

        Write-Host ("  DEL  [{0}] {1}" -f $d.Status, $d.InstanceId)
        & $pnputil.Source /remove-device $d.InstanceId | Out-Null

        if ($LASTEXITCODE -eq 0) {
            $removed++
        }
        else {
            Write-Warning ("  失敗 (exit {0}): {1}" -f $LASTEXITCODE, $d.InstanceId)
            $failed++
        }
    }

    Write-Host ("結果: 削除 {0} / 失敗 {1}" -f $removed, $failed)
    if ($failed -gt 0) { $ExitCode = 2 }
}

# --- 3) Bluetooth LE 列挙キー (任意) --------------------------------------
if ($IncludeBle) {
    Write-Section 'Bluetooth LE 列挙キー (BTHLE\DEV_*)'

    if (-not $isAdmin) {
        Write-Warning '非昇格のため BTHLE 配下を読めない場合があります（0 件 = 存在しない、とは限りません）。'
    }

    if (-not (Test-Path -LiteralPath $BleRoot)) {
        Write-Host '  BTHLE キーがありません。'
    }
    else {
        $keys = @(Get-ChildItem -LiteralPath $BleRoot -ErrorAction SilentlyContinue)
        Write-Host ("  DEV_* キー: {0}" -f $keys.Count)
        if (-not $isAdmin -and $keys.Count -eq 0) {
            Write-Warning '  0 件は権限不足の可能性があります。昇格して再実行してください。'
        }

        $targets = @()

        foreach ($k in $keys) {
            $subNames = @(Get-ChildItem -LiteralPath $k.PSPath -ErrorAction SilentlyContinue |
                          ForEach-Object { $_.PSChildName })
            $hitSub  = @($subNames | Where-Object { $_ -match '1D50|615E' })
            $hitSelf = [bool]($k.PSChildName -match '1D50|615E')

            if (-not ($hitSelf -or $hitSub.Count -gt 0)) { continue }

            # Properties サブキーの所有者を見る（削除を妨げるのはここ）
            $propsPath   = $k.PSPath + '\Properties'
            $propsExists = Test-Path -LiteralPath $propsPath
            $owner       = '-'
            $systemOwned = $false

            if ($propsExists) {
                try {
                    $owner = (Get-Acl -LiteralPath $propsPath -ErrorAction Stop).Owner
                    $systemOwned = [bool]($owner -match 'SYSTEM|TrustedInstaller')
                }
                catch {
                    $owner = '(acl-error)'
                }
            }

            $subText = if ($hitSub.Count -gt 0) { $hitSub -join ', ' } else { '-' }
            $note    = if ($systemOwned) { '  -> SYSTEM 所有: 管理者でも削除できない場合あり' } else { '' }

            Write-Host ("  {0}" -f $k.PSChildName)
            Write-Host ("    subkey : {0}" -f $subText)
            Write-Host ("    Props  : {0}  Owner: {1}{2}" -f $propsExists, $owner, $note)

            $targets += $k
        }

        if ($targets.Count -eq 0) {
            Write-Host '  ZMK の BTHLE キーは見つかりませんでした。'
        }
        elseif (-not $Apply) {
            Write-Host '  レポートのみ。-Apply で削除します。'
        }
        elseif (-not $isAdmin) {
            Write-Warning '削除には管理者権限が必要です。'
            $ExitCode = 1
        }
        else {
            $stamp     = Get-Date -Format 'yyyyMMdd_HHmmss'
            $backupDir = Join-Path $PSScriptRoot ('bthle_backup_' + $stamp)
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

            $index = 0
            foreach ($k in $targets) {
                $index++
                $fileName = '{0:D2}_{1}.reg' -f $index, ($k.PSChildName -replace '[^A-Za-z0-9_-]', '_')
                $regPath  = $k.Name -replace '^HKEY_LOCAL_MACHINE', 'HKLM'
                & reg.exe export $regPath (Join-Path $backupDir $fileName) /y | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning ("  バックアップ失敗: {0}" -f $regPath)
                }
            }
            Write-Host ("  バックアップ: {0}" -f $backupDir)

            $deleted  = 0
            $stubborn = @()

            foreach ($k in $targets) {
                try {
                    Remove-Item -LiteralPath $k.PSPath -Recurse -Force -ErrorAction Stop
                    Write-Host ("  削除: {0}" -f $k.PSChildName)
                    $deleted++
                }
                catch {
                    Write-Warning ("  削除失敗: {0} : {1}" -f $k.PSChildName, $_.Exception.Message)
                    $stubborn += $k
                }
            }

            Write-Host ("結果: 削除 {0} / 失敗 {1}" -f $deleted, $stubborn.Count)

            if ($stubborn.Count -gt 0) {
                $wrapper = New-SystemDeleteHelper -Keys $stubborn -BackupDir $backupDir
                Write-Host '  SYSTEM 権限での削除が必要です:' -ForegroundColor Yellow
                Write-Host ("   1) PsExec.exe を配置 : {0}" -f $backupDir)
                Write-Host ("      または同梱の    : {0}" -f (Join-Path $PSScriptRoot 'tools'))
                Write-Host ("   2) 管理者で実行      : {0}" -f $wrapper)
                Write-Host '   3) 完了後 PC を再起動'
                Write-Host '   手動: PsExec.exe -i -s regedit.exe で該当キーを削除'
                $ExitCode = 2
            }
        }
    }
}

# --- まとめ ---------------------------------------------------------------
Write-Host ''
if ($Apply) {
    Write-Host 'ヒント: キーボードを USB 接続し直すと、必要なら新しいエントリが作り直されます。'
    Write-Host ''
    Write-Host 'DYA Studio (Web Serial) の "WritableStream is locked" エラーが出る場合は、'
    Write-Host 'この削除後に PC を再起動してください（古い COM ポートのゴーストが原因のことがあります）。'
    Write-Host '再起動後、ブラウザで chrome://settings/content/serialPorts (Edge は edge://) を開き、'
    Write-Host '不要なポート許可を削除してから Studio を開き直すと確実です。'
}
else {
    Write-Host 'レポートのみの実行です。削除するには昇格した PowerShell で -Apply を付けてください:'
    Write-Host ("  powershell -ExecutionPolicy Bypass -File `"{0}`" -Apply" -f $PSCommandPath)
    Write-Host '  Bluetooth LE も対象にする場合は -IncludeBle を追加。'
}

if ($ExitCode -ne 0) { try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }; exit $ExitCode }
