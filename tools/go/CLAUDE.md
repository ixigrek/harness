## Go
- Toolchain and modules come from the Go proxy. `go build ./... && go vet ./...` before claiming done.
- `gofmt` on touched files. No new dependency without saying why.
- Tests: `go test ./... 2>&1 | tail -n 40`. Use `-v` or `-run` only on the failing test.
