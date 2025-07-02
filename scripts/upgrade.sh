source ./scripts/config.sh

sui client switch --address $admin

sui client upgrade --skip-dependency-verification --skip-fetch-latest-git-deps --upgrade-capability $upgrade_cap_id