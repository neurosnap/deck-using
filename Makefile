fmt:
	npx prettier@latest deck.md -w
.PHONY: fmt

gen: fmt
	npx @marp-team/marp-cli@latest deck.md -o deck.html
.PHONY: gen
