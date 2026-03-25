## Next.js
- App Router使用時はServer ComponentsとClient Componentsの境界を意識しろ
- `"use client"` は必要最小限のコンポーネントにのみ付けろ
- データフェッチはServer Componentsで行い、Client Componentsに渡せ
- `useEffect`で派生状態を計算するな。レンダー中に計算しろ
- Image, Link, Script等のNext.js最適化コンポーネントを使え
- Metadata APIでSEO対応しろ
