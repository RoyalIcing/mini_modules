.PHONY: dev
dev:
	iex -S mix phx.server

.PHONY: test
test:
	watchexec -c --exts ex,exs -- mix test --stale

.PHONY: production
production:
	fly deploy
