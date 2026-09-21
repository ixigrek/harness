## Python
- `uv` owns the environment: `uv sync`, then `uv run <cmd>`. Never `pip install` outside it.
- `uv run pytest 2>&1 | tail -n 40` before claiming done. `ruff format` and `ruff check` on touched files when the project configures ruff.
