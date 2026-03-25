## Python
- 型ヒントを必ず書け（Python 3.10+ の `|` 構文推奨）
- フォーマッターは `ruff format`、リンターは `ruff check` を使え
- 仮想環境は必須。`venv` か `poetry` を使え
- FastAPI使用時はPydanticモデルでリクエスト/レスポンスを型定義しろ
- `requirements.txt` または `pyproject.toml` でバージョン固定
