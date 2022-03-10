.PHONY: dev
dev:
	iex -S mix phx.server

.PHONY: test
test:
	watchexec -c --exts ex,exs -- mix test --stale

.PHONY: benchmark
benchmark:
	mix run test/mini_modules/universal_modules/parser_sample.exs

.PHONY: production
production:
	fly deploy --remote-only

.PHONY: logs
logs:
	fly logs

TEMPLATE_MARKDOWN := $(wildcard lib/mini_modules_web/templates/**/*.md)

$(TEMPLATE_MARKDOWN):
	@echo $(firstword $(shell shasum -a 256 $@))
	@aws s3 cp $@ s3://collected-workspaces/sha256/text/markdown/$(firstword $(shell shasum -a 256 $@)) --acl public-read
	@curl "https://collected.press/1/s3/object/us-west-2/collected-workspaces/sha256/text/markdown/$(firstword $(shell shasum -a 256 $@))" --silent -o $(addsuffix .html.heex,$(basename $@))

.PHONY: templates
templates: $(TEMPLATE_MARKDOWN)
	