# zmk-device-cleanup

Windows に残った **ZMK キーボードのゴースト（幽霊）デバイス**を検出して削除する小さなツールです。
デバイスマネージャーに残り続ける `Unknown` / `Error` 状態の HID / USB エントリを、必要なものだけ安全に消します。

- 既定は **レポートのみ**（何も変更しません）
- 削除するのは `Status = Unknown`（ゴースト）と `Status = Error`（Code 10 の個体）のエントリだけ（接続中のデバイスはスキップ）
- 対象は **VID_1D50 全体**（PID 615E / 6160 など ZMK 系の複数世代をまとめて処理）
- ドライバーストア（`pnputil /delete-driver`）には触りません
- Bluetooth LE の列挙キー掃除はオプション（`.reg` バックアップ付き）

```
実測例（このツールが対象にする典型パターン）

  Status 'Unknown': 17 devices / Status 'Error': 1 device
  [Error]    USB       USB\VID_1D50&PID_615E\F6CFB0968BA2C3CA   <- Code 10 (USB Composite)
  [Unknown]  Keyboard  HID\VID_1D50&PID_615E&COL01\6&1F856D2&0&0000
  [Unknown]  Mouse     HID\VID_1D50&PID_615E&COL03\6&1F856D2&0&0002
  [Unknown]  USB       USB\VID_1D50&PID_6160\F6CFB0968BA2C3CA   <- 別世代ファームの残骸
  [Unknown]  Ports     USB\VID_1D50&PID_615E&MI_00\6&15ABDFF&0&0000  <- 古い COM ポート
```

## 症状と原因

ZMK ファームウェアのキーボードは、USB の VID/PID に既定値 **`1D50:615E`** を使います。
ケーブルを抜くと PnP エントリは `Status = Unknown` のまま `HKLM\SYSTEM\CurrentControlSet\Enum\` に残り、
次のような症状の原因になります。

- デバイスマネージャー（非表示デバイス表示）に「不明なデバイス」が増え続ける
- 同じ VID/PID の別個体を繋いだときに、古い設定やレポート記述子が干渉することがある
- **Windows のみで USB が認識されない（Code 10 / CM_PROB_FAILED_START）**
  → 破損した個体エントリを Windows が「前回失敗した個体」として再現するため
- **DYA Studio / Web Serial で「WritableStream is locked」**
  → 古い COM ポート（ゴースト）がポート一覧に残り、開こうとしたポートがロック扱いになることがある
  （削除後はブラウザのシリアルポート許可もリセットすると確実）
- ペアリング一覧に、もう使っていない同じキーボードが残り続ける

> Android では USB が動くのに Windows だけ Code 10 になる場合は、ファームではなく
> このゴーストデバイスが原因の可能性が高いです（実例: docs/ 参照）。

Windows 純正の GUI では「Unknown / Error だけ選んで消す」がしづらいので、本ツールはそこだけを対象にします。

## これは何を直さないか

本ツールが消すのは **Windows に残った過去のエントリ**だけです。
次は Windows 側の問題ではないため、このツールでは直りません。

| 症状 | 対処する場所 |
|---|---|
| スキャン／アドバタイズが始まらず、そもそも再ペアリングできない | キーボードのファームウェア（ZMK 側） |
| 接続は維持されているのにキー入力が止まる／MCU が落ちる | キーボードのファームウェア（ZMK 側） |
| ペアリング一覧に同じキーボードが二重に残る | 本ツール（BLE エントリの掃除） |

例えば MeKaBu / MKB2 の `zmk-0.4-20261031-bt-recovery-rc.1` は、
スキャン／広告開始の失敗に対する 1・2・4・8・16 秒の再試行を ZMK 側に追加したリリースで、
Windows のレジストリには触れません。両者は別の層の問題です。

## 動作環境

| 項目 | 要件 |
|---|---|
| OS | Windows 10 1809 以降 / Windows 11 |
| PowerShell | 5.1（標準）または 7.x |
| 権限 | レポートは不要。**削除時のみ管理者権限**（UAC） |
| 外部コマンド | `pnputil.exe`（標準搭載）、BLE 削除時のみ任意で PsExec（`tools\` に置けば自動使用） |

## 使い方

### いちばん簡単（ダブルクリック）

1. キーボードの USB ケーブルを抜く
2. `zmk_device_cleanup_apply.bat` をダブルクリック
3. 一覧を確認して `Y` を入力
4. UAC ダイアログで「はい」
5. 完了したら PC を再起動（DYA Studio を使う場合は特に推奨）

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
| `-Apply` | `Status = Unknown` / `Error` のエントリを `pnputil /remove-device` で削除 |
| `-IncludeBle` | `HKLM\SYSTEM\CurrentControlSet\Enum\BTHLE\DEV_*` も調査（`-Apply` 併用時は `.reg` にバックアップ） |

## 終了コード

| コード | 意味 |
|---|---|
| 0 | 正常（レポート完了／削除成功） |
| 1 | 管理者権限が必要（削除要求を拒否） |
| 2 | 一部の削除に失敗（BLE は PsExec ヘルパーを生成） |
| 3 | 環境エラー（`Get-PnpDevice` / `pnputil` が使えない） |

## 安全設計

- **削除対象は `Status = Unknown` と `Error` のみ。** 接続中のデバイス（`OK`）は必ずスキップします
- 削除前に `Y/N` の確認（`apply` 用バッチ）
- ドライバーパッケージは削除しません（`/remove-device` は個体エントリのみ）
- BLE の削除時は、対象キーを `.reg` にエクスポートしてから実行します
- `Properties` サブキーが SYSTEM 所有で消せない場合は、無理に権限を書き換えず
  **PsExec 用のヘルパー `.bat` を生成**して手順を提示します

## 仕組み

1. `Get-PnpDevice` で `InstanceId` に `VID_1D50` を含むエントリを列挙（PID は 615E / 6160 等すべて）
2. `Status` を表示（`OK` = 接続中 / `Unknown` = ゴースト / `Error` = Code 10）
3. `-Apply` のとき、`Unknown` / `Error` のものだけ `pnputil /remove-device <InstanceId>` で削除
4. `-IncludeBle` のとき、`Enum\BTHLE\DEV_*` 配下の `VID&00011D50_PID&615E` サブキーを調査
   （レジストリの `Enum` は SYSTEM 所有のため、削除は `Remove-Item` → 失敗時は PsExec 手順）

詳しい内部動作は [docs/how-it-works.md](docs/how-it-works.md) を参照してください。

## 別の VID/PID に使う

`zmk_device_cleanup.ps1` の先頭付近にある定数を書き換えれば、他のキーボードにも使えます。

```powershell
$VidPattern = 'VID_1D50'   # ← 例: 'VID_1209'（ベンダー ID のみ指定）
```

BLE 側は該当サブキー名（`1D50` / `615E`）も合わせて変更してください。

## アンインストール

ファイルを削除するだけです。常駐プロセス・サービス・スタートアップ登録はありません。
削除したゴーストエントリは元に戻りませんが、キーボードを繋ぎ直せば新しいエントリが作られます。

## トラブルシューティング

[docs/troubleshooting.md](docs/troubleshooting.md) を参照してください。

## 制限事項

- 対象は既定で **ZMK の VID `1D50` 全体**（定数変更で対応可能）
- Windows 専用（Linux / macOS では動きません）
- BLE のレジストリ削除は環境によっては SYSTEM 権限が必要で、自動では完結しません
- 削除後に再起動を求められる場合があります（通常は不要。DYA Studio 使用時は推奨）

## 変更履歴

[CHANGELOG.md](CHANGELOG.md) を参照してください。

## ライセンス

[MIT](LICENSE)

---

## English

A small Windows tool that finds and removes **stale (ghost) ZMK keyboard devices**
(`Status = Unknown` / `Error` HID/USB entries left behind under `VID_1D50`, covering
all ZMK-family PIDs such as `615E` and `6160`).

- Report-only by default — nothing is changed
- Removes **only** entries with `Status = Unknown` or `Error` (Code 10); connected devices are skipped
- Never touches the driver store (`pnputil /remove-device` only)
- Optional Bluetooth LE registry cleanup with `.reg` backup

Quick start: unplug the keyboard, double-click `zmk_device_cleanup_apply.bat`,
review the list, press `Y`, and approve the UAC prompt.

Requirements: Windows 10 1809+ / Windows 11, PowerShell 5.1 or 7.x.
