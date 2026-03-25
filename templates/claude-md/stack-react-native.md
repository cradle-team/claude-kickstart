## React Native / Expo
- Expo Routerを使用する場合はファイルベースルーティングのルールに従え
- ネイティブモジュールが必要な場合はExpo Dev Clientを使え
- プラットフォーム固有のコードは `.ios.tsx` / `.android.tsx` で分離
- パフォーマンスが問題になるリストは `FlashList` を検討しろ
- `console.log` は本番ビルドから除外しろ（babel-plugin-transform-remove-console）
