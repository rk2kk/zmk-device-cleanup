# トラブルシューティング

## 何も表示されない（件数 0）

本当に対象が無いか、VID/PID が違うかのどちらかです。まずキーボードを USB 接続して確認します。

```powershell
# 接続中のキーボードのハードウェア ID を確認
Get-PnpDevice -Class Keyboard -Status OK |
    Select-Object FriendlyName, InstanceId
```

`InstanceId` が `VID_1D50&PID_615E` でなければ、ファームウェアが別の VID/PID を使っています。
`zmk_device_cleanup.ps1` の `$VidPattern` を実際の値に書き換えてください。
デバイスマネージャーの「ハードウェア ID」でも確認できます。

## `Status` が `OK` のままで削除されない

接続中です。ケーブルを抜いてから実行してください。
本ツールは `OK` のエントリを意図的にスキップします（動作中のデバイスを消さないため）。

## 削除が `Access denied` で失敗する

管理者権限で動いていません。

```bat
zmk_device_cleanup.bat apply
```

を実行し、UAC ダイアログで「はい」を選んでください。
`Elevated : True` と表示されていれば昇格しています。

## `pnputil.exe` が見つからない

Windows 10 1809 以降が必要です。`C:\Windows\System32\pnputil.exe` の存在を確認してください。
非常に古い環境では `devcon.exe`（WDK 同梱）で代替できますが、本ツールは対象外です。

## BLE が 0 件と表示される

```
警告: 非昇格のため BTHLE 配下を読めない場合があります
```

管理者権限で再実行してください。それでも 0 件なら、USB 接続のみで使っていて
BLE のペアリング履歴が無い可能性があります。

## BLE キーが削除できない（SYSTEM 所有）

```
削除失敗: DEV_xxxxxxxxxxxx : ... アクセスが拒否されました。
```

`Enum` 配下の `Properties` サブキーは SYSTEM 所有で、管理者でも削除できないことがあります。
ツールはこの場合、バックアップフォルダに次の2ファイルを生成します。

```
bthle_backup_<日時>\
├── system_delete.bat
├── run_as_system_psexec.bat
└── *.reg                  ← 削除前のバックアップ
```

手順:

1. `PsExec.exe` を用意する（同梱の `tools\PsExec.exe` があれば自動で使われます。
   無ければ [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) を展開して
   `bthle_backup_<日時>\` に置く）
2. `run_as_system_psexec.bat` を**管理者として実行**
3. 削除用のウィンドウが開くので、内容を確認して完了させる
4. PC を再起動

手動で行う場合:

```bat
PsExec.exe -i -s regedit.exe
```

で SYSTEM 権限の regedit を開き、該当キーを削除します。

## 日本語が文字化けする

- `zmk_device_cleanup.ps1` は **UTF-8 BOM 付き**で保存されています。編集するときも BOM を維持してください
- 古いコンソールで文字化けする場合は Windows Terminal か PowerShell 7 で実行してください
- `.bat` 側は ASCII のみで書かれています（`cmd.exe` のコードページに依存しないため）

## 「このスクリプトは実行できません」と出る

実行ポリシーでブロックされています。同梱の `.bat` は `-ExecutionPolicy Bypass` を指定するので、
`.bat` 経由なら通常は発生しません。直接 `.ps1` を実行する場合のみ次を使います。

```powershell
powershell -ExecutionPolicy Bypass -File .\zmk_device_cleanup.ps1
```

ダウンロードした zip 由来の場合:

```powershell
Unblock-File .\zmk_device_cleanup.ps1
```

## SmartScreen / ウイルス対策で止められる

署名のないスクリプトが「レジストリ削除」「`pnputil`」を呼ぶため、ヒューリスティックに引っかかることがあります。
内容は全ファイル 300 行未満で読めるので、必要なら実行前に確認してください。
組織のポリシーで実行できない場合は、管理者に依頼するか手動で `pnputil` を実行してください。

## 削除したのにまた増える

同じ VID/PID のキーボードを複数使っている、またはファームウェアを書き換えるたびに
Windows が新しい個体として登録している可能性があります。ゴースト自体は実害が少ないため、
増えて困ったときだけ再実行する運用で問題ありません。

## ネットワークドライブ・クラウド同期フォルダ上で実行できる？

実行できます。`.bat` は `%~dp0`、`.ps1` は `$PSScriptRoot` を使うため、
日本語やスペースを含むパスでも動作します。
ただし Google ドライブ等の同期中に実行すると、生成したバックアップの同期が遅れることがあります。
気になる場合はローカル（例: `C:\Tools\`）にコピーしてから実行してください。

## 誤って必要なデバイスを消した

キーボードを接続し直せば、Windows が新しいエントリを自動で作り直します。
ドライバーパッケージは削除していないため、再インストールは不要です。
