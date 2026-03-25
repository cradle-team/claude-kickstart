## Flutter
- `flutter analyze` の警告を全て解消しろ
- Widgetの分割を意識しろ。1つのWidgetが大きくなりすぎたら分割
- 状態管理は `Riverpod` か `Bloc` を使え。`setState` は最小限
- プラットフォーム固有のコードは `Platform.isIOS` / `Platform.isAndroid` で分岐
- `const` コンストラクタを積極的に使え（リビルド最適化）
