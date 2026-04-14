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

Web ビルドのデプロイは `.github/workflows/deploy-pages.yml` が `main` への push で実行します（初回のみリポジトリの **Settings → Pages** で source を **GitHub Actions** にしてください）。

公開 URL: [https://blurbrah.github.io/c2pa_ai_gallery_probe/](https://blurbrah.github.io/c2pa_ai_gallery_probe/)

workflow 内でリポジトリ名から `--base-href` を組み立てているため、リポジトリ名を `c2pa_ai_gallery_probe` のまま使う限り追加の base-href 修正は不要です。

## Notes

- `c2pa_flutter 0.1.0` の high-level API だけだと `digitalSourceType` を取りこぼすケースがあるため、ネイティブ側は raw JSON を解析しています
- `C2PA マニフェストがない = AI 画像ではない` ではありません
- macOS / Windows / Linux はこの検証アプリの主対象外です
