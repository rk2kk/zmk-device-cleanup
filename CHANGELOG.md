# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/lang/ja/).

## [Unreleased]

### Docs

- README に「これは何を直さないか」を追加。スキャン／広告開始の失敗や MCU 停止は
  ZMK ファームウェア側の領域で、本ツールの対象外であることを明示
- 症状リストから未検証の「HID の列挙が不安定になる／キー入力が一瞬おかしくなる」を削除し、
  代わりに「ペアリング一覧に古いキーボードが残り続ける」を追加
- `docs/troubleshooting.md` に `settings_reset.uf2` 後の後片付け手順を追加
  （キーボード側の設定消去と Windows 側のエントリ削除は両方必要）

## [1.2.0] - 2026-10-30

### Added

- 削除後に DYA Studio / Web Serial の「WritableStream is locked」対策手順を表示
  （PC 再起動 + ブラウザのシリアルポート許可のリセットを案内）

### Changed

- 対象 VID を `VID_1D50&PID_615E` 固定から **`VID_1D50` 全体** に拡大
  （PID 615E / 6160 など ZMK 系の複数世代のゴーストをまとめて掃除できる）
- 削除対象を `Status = Unknown` のみから **`Unknown` + `Error`（Code 10）** に拡大
  （「Error の USB Composite Device が削除されず残る」実害への対応）

### Fixed

- 実行結果ベースの改善: `Error` ステータスのデバイスが SKIP されて
  ゴーストが残り続ける問題を修正

## [1.1.0] - 2026-10-30

### Added

- `zmk_device_cleanup_apply.bat` — ダブルクリックで「レポート → Y/N 確認 → UAC 昇格 → 削除」まで実行するランチャー
- 昇格先プロセスの終了を待ち、終了コードを引き継ぐように変更（`Start-Process -PassThru -Wait`）
- 終了コードを整理（0=正常 / 1=権限不足 / 2=一部失敗 / 3=環境エラー）
- `-IncludeBle` 実行時の `.reg` バックアップ、PsExec ヘルパー `.bat` の自動生成
- コメントベースのヘルプ（`.SYNOPSIS` / `.EXAMPLE`）

### Fixed

- レジストリ所有者の取得が常に失敗していた問題を修正
  （`Registry::MACHINE\...` という不正パスを組み立てていた）
- 生成するヘルパー `.bat` が `-Encoding Ascii` で日本語パスを `??????` に壊していた問題を修正
  （`%~dp0` で解決するよう変更）
- 非昇格時に BLE キーが 0 件でも「存在しない」と表示していた問題を修正（権限不足の警告を追加）
- UTF-8 BOM 無しによる Windows PowerShell 5.1 での日本語文字化けを修正

### Changed

- 削除対象を `Status = Unknown` に限定する意図をコード上でも明示
- `pnputil.exe` / `Get-PnpDevice` の存在・例外チェックを追加

## [1.0.0] - 2026-10-22

### Added

- 初版（レポート / USB・HID のゴースト削除 / BLE 列挙キー調査）
