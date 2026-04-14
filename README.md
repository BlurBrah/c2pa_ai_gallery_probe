# c2pa_ai_gallery_probe

Flutter で C2PA を検証するためのサンプルです。  
画像を選択して、C2PA マニフェストの有無、`digitalSourceType` ベースの AI 関連シグナル、`issuer`、`claimGenerator` などを確認できます。

## Platforms

- Web: `c2pa-js` を `web/index.html` から lazy init して利用
- iOS / Android: `c2pa_flutter` の Rust reader JSON を直接読み取り

Web とモバイルで同じ `C2paResult` に寄せていますが、実装経路は分けています。

## Local Run

```bash
flutter pub get
flutter run -d chrome
```

モバイルは通常どおり `flutter run` で起動できます。

## GitHub Pages

このディレクトリを単独リポジトリ `c2pa_ai_gallery_probe` として切り出す前提で、GitHub Pages 用 workflow を同梱しています。

公開 URL 想定:

```text
https://blurbrah.github.io/c2pa_ai_gallery_probe/
```

### 単独リポジトリ化の最短手順

```bash
cd ai-playground/c2pa_ai_gallery_probe
git init
git add .
git commit -m "Initial commit"
git branch -M main
gh repo create BlurBrah/c2pa_ai_gallery_probe --public --source=. --remote=origin --push
```

### Pages 設定

1. GitHub 側で repository を作成
2. `Settings > Pages` で build source を `GitHub Actions` にする
3. `main` に push すると `.github/workflows/deploy-pages.yml` が `flutter build web` を実行して公開

workflow では repository 名から `--base-href` を自動計算するので、`c2pa_ai_gallery_probe` のまま公開する限り追加修正は不要です。

## Notes

- `c2pa_flutter 0.1.0` の high-level API だけだと `digitalSourceType` を取りこぼすケースがあるため、ネイティブ側は raw JSON を解析しています
- `C2PA マニフェストがない = AI 画像ではない` ではありません
- macOS / Windows / Linux はこの検証アプリの主対象外です
