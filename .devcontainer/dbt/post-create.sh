#!/usr/bin/env bash
# 依存の確認だけを行う。dbt init やモデル作成はしない。
set -euo pipefail

echo "python=$(command -v python)"
python --version
echo "dbt=$(command -v dbt)"
dbt --version

# 既存プロジェクトの transform/dap_dbt があるときだけ、その依存を入れる。
if [ -d transform/dap_dbt ]; then
  cd transform/dap_dbt
  uv sync
fi
