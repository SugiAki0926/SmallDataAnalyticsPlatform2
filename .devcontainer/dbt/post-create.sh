#!/usr/bin/env bash
# uv sync で Python 依存を入れ、dbt deps と pre-commit を有効化する。
# dbt deps（codegen 等）は dbt パッケージであり、uv の対象ではない。
set -euo pipefail

cd /workspaces/SmallDataAnalyticsPlatform2

uv sync

export PATH="/workspaces/SmallDataAnalyticsPlatform2/.venv/bin:${PATH}"

echo "python=$(command -v python)"
python --version
echo "dbt=$(command -v dbt)"
dbt --version

cd /workspaces/SmallDataAnalyticsPlatform2/transform/dap2
dbt deps

cd /workspaces/SmallDataAnalyticsPlatform2
echo "pre-commit=$(command -v pre-commit)"
pre-commit --version
# pre-commit install 学習用なので、precommitを動かす時以外はいったコメントアウト
echo "sqlfluff=$(command -v sqlfluff)"
sqlfluff --version
