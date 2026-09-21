## Token hygiene
- Grep/Glob before Read. Never dump whole large files or directory trees into context.
- Tests: pipe through `tail -n 40`. Verbose output or a single-test filter only on the failing test.
- No progress narration. Short answers. Code, commands and errors byte-exact.
