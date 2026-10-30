# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/lang/ja/).

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
