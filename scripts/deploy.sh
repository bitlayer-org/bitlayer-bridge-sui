source ./scripts/config.sh

sui client switch --address $admin

sui client publish --skip-fetch-latest-git-deps --skip-dependency-verification
