# .PHONY build

all:
	sui move build --skip-fetch-latest-git-deps

test:
	sui move test --skip-fetch-latest-git-deps

fast:
	sui move build --skip-fetch-latest-git-deps

deploy:
	sui client publish --skip-fetch-latest-git-deps --skip-dependency-verification

