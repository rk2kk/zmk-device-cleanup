# tools/（任意）

`PsExec.exe` を置くフォルダです。**リポジトリには含めていません**
（Microsoft の配布物でサイズも大きいため、`.gitignore` で除外しています）。

## 取得方法

1. <https://learn.microsoft.com/sysinternals/downloads/psexec> から `PsTools.zip` を取得
2. 展開して `PsExec.exe`（64bit 環境なら `PsExec64.exe` も）をこのフォルダに置く

## 使われる場面

`-IncludeBle -Apply` で BLE の列挙キーが SYSTEM 所有のために削除できなかったときだけです。
ツールが生成する `run_as_system_psexec.bat` は、次の順に `PsExec.exe` を探します。

1. `bthle_backup_<日時>\PsExec.exe`
2. `tools\PsExec.exe` ← ここ

USB / HID の削除（`pnputil /remove-device`）には PsExec は不要です。

## ローカル確認済みの内容

| ファイル | 版 | Authenticode 署名 |
|---|---|---|
| `PsExec.exe` | 2.43 | Microsoft Corporation（Valid） |
| `PsExec64.exe` | 2.43 | Microsoft Corporation（Valid） |
| `Eula.txt` | - | Sysinternals EULA |

取得元: `https://download.sysinternals.com/files/PSTools.zip`

> Windows Defender などのセキュリティ製品が PsExec を「HackTool」として
> 検知・隔離する場合があります。その場合は除外設定を行うか、
> 手動で `PsExec.exe -i -s regedit.exe` を実行して削除してください。
