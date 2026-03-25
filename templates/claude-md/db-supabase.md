
## Supabase
- **全テーブルにRLS必須。例外なし**
- anon keyで読めるデータを最小限にしろ。公開不要なテーブルはSELECTも塞げ
- RLS追加後は必ず `anon` ロールでクエリして検証しろ
- service_roleキーをクライアントサイドに絶対漏らすな
- Edge Functionsを使う場合はDeno Deployの制約を意識しろ
