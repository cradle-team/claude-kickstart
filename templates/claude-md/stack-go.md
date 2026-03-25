## Go
- `go vet` と `golangci-lint` を必ず通せ
- エラーは必ずハンドリングしろ。`_` で握りつぶすな
- goroutineのリークに注意。`context` でキャンセルを伝搬しろ
- インターフェースは使う側で定義しろ（Accept interfaces, return structs）
- `init()` 関数は極力使うな。明示的な初期化を推奨
