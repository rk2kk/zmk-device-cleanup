# 内部動作

このツールが何をしているのかを、Windows の PnP・レジストリの観点から説明します。

## 1. ゴーストデバイスとは

USB デバイスを接続すると、Windows は次の場所に「個体エントリ」を作ります。

```
HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_1D50&PID_615E\<シリアル/インスタンス>
HKLM\SYSTEM\CurrentControlSet\Enum\HID\VID_1D50&PID_615E&COL01\<インスタンス>
```

ケーブルを抜くと、エントリ自体は削除されず `Status = Unknown`（非存在）として残ります。
これが「ゴースト」です。デバイスマネージャーの「非表示のデバイスを表示」で見えます。

ZMK のキーボードは VID/PID が `1D50:615E` 固定なので、
**別のキーボード・別のファームウェア書き込みでも同じ VID/PID のエントリが積み上がります。**
Windows は個体（シリアル）単位で別エントリとして扱うため、同じ機種でも増えていきます。

## 2. 検出

```powershell
Get-PnpDevice | Where-Object { $_.InstanceId -match 'VID_1D50&PID_615E' }
```

`Get-PnpDevice` は CIM（`Win32_PnPEntity`）をラップしたもので、管理者権限なしでも列挙できます。
`Status` は次の意味です。

| Status | 意味 |
|---|---|
| `OK` | 現在接続中（または有効） |
| `Unknown` | 過去に存在したが今は無い＝ゴースト |
| `Error` | 存在するが問題あり |

本ツールは **`Unknown` のみ**を削除対象にします。`OK` と `Error` は触りません。

## 3. 削除（USB / HID）

```powershell
pnputil.exe /remove-device "HID\VID_1D50&PID_615E&COL01\6&1F856D2&0&0000"
```

- `pnputil /remove-device` は **個体エントリ**を削除します（Windows 10 1809 以降）
- ドライバーパッケージは削除しません。ドライバーストアを消すのは `/delete-driver` で、これは別操作です
- 管理者権限が必要です（`ERROR_ACCESS_DENIED` で失敗します）

削除の順序は問いません。親の `USB\...` を消しても、子の `HID\...` は個別に消せます。

## 4. Bluetooth LE（任意）

BLE のペアリング履歴は `Enum\BTHLE` 配下に残ります。

```
HKLM\SYSTEM\CurrentControlSet\Enum\BTHLE\DEV_<MAC>
└── VID&00011D50_PID&615E     ← ZMK の VID/PID を持つサブキー
```

- `DEV_<MAC>` がデバイス個体
- その下の `VID&00011D50_PID&615E` が「その個体が名乗った VID/PID」
- `Properties` サブキーに PnP のプロパティが入る

この領域は **SYSTEM 所有**で、管理者 (Administrators) でも `WRITE_DAC` を持たないことがあります。
そのため次の順で試します。

1. `.reg` にバックアップ（`reg.exe export`）
2. `Remove-Item -Recurse -Force` を試す
3. 失敗したら **PsExec ヘルパーを生成**（所有権を書き換えず、SYSTEM 権限で `reg delete` する）

> 所有権を強制的に Administrators へ変える方法もありますが、
> 失敗すると中途半端な ACL が残るため、本ツールは採用していません。

## 5. 安全側に倒している点

| 危険 | 対策 |
|---|---|
| 接続中のデバイスを消す | `Status -ne 'Unknown'` は必ずスキップ |
| ドライバーを壊す | `/remove-device` のみ。`/delete-driver` は使わない |
| BLE キーを消しすぎる | `VID&00011D50_PID&615E` を持つキーだけ。事前に `.reg` バックアップ |
| 日本語パスで壊れる | 生成する `.bat` は `%~dp0` で自己解決（実パスを書かない） |
| 権限の取り違え | 削除系は非昇格なら即座に中断して終了コード 1 |

## 6. コードマップ

`zmk_device_cleanup.ps1`

| 関数 / ブロック | 役割 |
|---|---|
| `Test-IsAdmin` | 昇格判定 |
| `Write-Section` | 見出し表示 |
| `New-SystemDeleteHelper` | PsExec 用 `.bat` の生成（`system_delete.bat` / `run_as_system_psexec.bat`） |
| `# --- 1) PnP エントリのレポート` | 列挙と表示 |
| `# --- 2) 削除 (USB / HID)` | `pnputil /remove-device` |
| `# --- 3) Bluetooth LE 列挙キー` | BTHLE の調査・バックアップ・削除 |

`zmk_device_cleanup.bat` / `zmk_device_cleanup_apply.bat`

| ファイル | 役割 |
|---|---|
| `zmk_device_cleanup.bat` | 引数解析（`apply` / `ble` / `/nopause`）、PowerShell ホスト選択、UAC 昇格、終了コード表示 |
| `zmk_device_cleanup_apply.bat` | ダブルクリック用。レポート → Y/N 確認 → 昇格して `-Apply` |

PowerShell ホストは `pwsh.exe` があれば優先し、無ければ `powershell.exe`（5.1）を使います。
スクリプトは UTF-8 BOM 付きなので、5.1 でも日本語が文字化けしません。
