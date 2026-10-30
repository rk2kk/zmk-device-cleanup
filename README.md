# zmk-device-cleanup

Windows に残った **ZMK キーボードのゴースト（幽霊）デバイス**を検出して削除する小さなツールです。
デバイスマネージャーに残り続ける `Unknown` 状態の HID / USB エントリを、必要なものだけ安全に消します。

- 既定は **レポートのみ**（何も変更しません）
- 削除するのは `Status = Unknown` のエントリだけ（接続中のデバイスはスキップ）
- ドライバーストア（`pnputil /delete-driver`）には触りません
- Bluetooth LE の列挙キー掃除はオプション（`.reg` バックアップ付き）

```
実測例（このツールが必要になる典型パターン）

  Status 'Unknown': 4 devices
  [Unknown] Keyboard  HID\VID_1D50&PID_615E&COL01\6&1F856D2&0&0000
  [Unknown] HIDClass  HID\VID_1D50&PID_615E&COL02\6&1F856D2&0&0001
  [Unknown] Mouse     HID\VID_1D50&PID_615E&COL03\6&1F856D2&0&0002
  [Unknown] HIDClass  USB\VID_1D50&PID_615E\C37E366DC802684A
```

## 症状と原因

ZMK ファームウェアのキーボードは、USB の VID/PID に既定値 **`1D50:615E`** を使います。
ケーブルを抜くと PnP エントリは `Status = Unknown` のまま `HKLM\SYSTEM\CurrentControlSet\Enum\` に残り、
次のような症状の原因になります。

- デバイスマネージャー（非表示デバイス表示）に「不明なデバイス」が増え続ける
- 同じ VID/PID の別個体を繋いだときに、古い設定やレポート記述子が干渉することがある
- HID の列挙が不安定になる／キー入力が一瞬おかしくなる

Windows 純正の GUI では「Unknown だけ選んで消す」がしづらいので、本ツールはそこだけを対象にします。

## 動作環境

| 項目 | 要件 |
|---|---|
| OS | Windows 10 1809 以降 / Windows 11 |
| PowerShell | 5.1（標準）または 7.x |
| 権限 | レポートは不要。**削除時のみ管理者権限**（UAC） |
| 外部コマンド | `pnputil.exe`（標準搭載）、BLE 削除時のみ任意で PsExec |

## 使い方

### いちばん簡単（ダブルクリック）

1. キーボードの USB ケーブルを抜く
2. `zmk_device_cleanup_apply.bat` をダブルクリック
3. 一覧を確認して `Y` を入力
4. UAC ダイアログで「はい」

削除結果は昇格後のウィンドウに表示されます。

### 確認だけしたい

`zmk_device_cleanup.bat` をダブルクリック（またはコマンドプロンプトから引数なしで実行）。
**何も変更しません。**

### コマンドライン

```bat
:: レポートのみ
zmk_device_cleanup.bat

:: 削除（UAC で自動昇格）
zmk_device_cleanup.bat apply

:: Bluetooth LE の列挙キーも調査
zmk_device_cleanup.bat ble

:: 削除 + BLE
zmk_device_cleanup.bat apply ble

:: 終了時にキー入力を待たない
zmk_device_cleanup.bat apply /nopause
```

PowerShell から直接呼ぶ場合:

```powershell
.\zmk_device_cleanup.ps1              # レポート
.\zmk_device_cleanup.ps1 -Apply       # 削除（昇格必須）
.\zmk_device_cleanup.ps1 -IncludeBle  # BLE も調査
```

## オプション

| オプション | 説明 |
|---|---|
| `-Apply` | `Status = Unknown` のエントリを `pnputil /remove-device` で削除 |
| `-IncludeBle` | `HKLM\SYSTEM\CurrentControlSet\Enum\BTHLE\DEV_*` も調査（`-Apply` 併用時は `.reg` にバックアップ） |

## 終了コード

| コード | 意味 |
|---|---|
| 0 | 正常（レポート完了／削除成功） |
| 1 | 管理者権限が必要（削除要求を拒否） |
| 2 | 一部の削除に失敗（BLE は PsExec ヘルパーを生成） |
| 3 | 環境エラー（`Get-PnpDevice` / `pnputil` が使えない） |

## 安全設計

- **削除対象は `Status = Unknown` のみ。** 接続中のデバイスは `SKIP (接続中)` として必ず残します
- 削除前に `Y/N` の確認（`apply` 用バッチ）
- ドライバーパッケージは削除しません（`/remove-device` は個体エントリのみ）
- BLE の削除時は、対象キーを `.reg` にエクスポートしてから実行します
- `Properties` サブキーが SYSTEM 所有で消せない場合は、無理に権限を書き換えず
  **PsExec 用のヘルパー `.bat` を生成**して手順を提示します

## 仕組み

1. `Get-PnpDevice` で `InstanceId` に `VID_1D50&PID_615E` を含むエントリを列挙
2. `Status` を表示（`OK` = 接続中 / `Unknown` = ゴースト）
3. `-Apply` のとき、`Unknown` のものだけ `pnputil /remove-device <InstanceId>` で削除
4. `-IncludeBle` のとき、`Enum\BTHLE\DEV_*` 配下の `VID&00011D50_PID&615E` サブキーを調査
   （レジストリの `Enum` は SYSTEM 所有のため、削除は `Remove-Item` → 失敗時は PsExec 手順）

詳しい内部動作は [docs/how-it-works.md](docs/how-it-works.md) を参照してください。

## 別の VID/PID に使う

`zmk_device_cleanup.ps1` の先頭付近にある定数を書き換えれば、他のキーボードにも使えます。

```powershell
$VidPattern = 'VID_1D50&PID_615E'   # ← 例: 'VID_1209&PID_0001'
```

BLE 側は該当サブキー名（`1D50` / `615E`）も合わせて変更してください。

## アンインストール

ファイルを削除するだけです。常駐プロセス・サービス・スタートアップ登録はありません。
削除したゴーストエントリは元に戻りませんが、キーボードを繋ぎ直せば新しいエントリが作られます。

## トラブルシューティング

[docs/troubleshooting.md](docs/troubleshooting.md) を参照してください。

## 制限事項

- 対象は既定で **ZMK の `1D50:615E` 固定**（定数変更で対応可能）
- Windows 専用（Linux / macOS では動きません）
- BLE のレジストリ削除は環境によっては SYSTEM 権限が必要で、自動では完結しません
- 削除後に再起動を求められる場合があります（通常は不要）

## 変更履歴

[CHANGELOG.md](CHANGELOG.md) を参照してください。

## ライセンス

[MIT](LICENSE)

---

## English

A small Windows tool that finds and removes **stale (ghost) ZMK keyboard devices**
(`Status = Unknown` HID/USB entries left behind under `VID_1D50&PID_615E`).

- Report-only by default — nothing is changed
- Removes **only** entries with `Status = Unknown`; connected devices are skipped
- Never touches the driver store (`pnputil /remove-device` only)
- Optional Bluetooth LE registry cleanup with `.reg` backup

Quick start: unplug the keyboard, double-click `zmk_device_cleanup_apply.bat`,
review the list, press `Y`, and approve the UAC prompt.

Requirements: Windows 10 1809+ / Windows 11, PowerShell 5.1 or 7.x.
