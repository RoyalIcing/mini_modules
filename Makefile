.PHONY: dev
dev:
	iex -S mix phx.server

.PHONY: test
test:
	watchexec -c --exts ex,exs -- mix test --stale

.PHONY: sample
sample:
	mix run test/mini_modules/universal_modules/parser_sample.exs

.PHONY: production
production:
	fly deploy
