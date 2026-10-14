#!/bin/bash
# SessionStart hook for Claude Code cloud sessions:
# starts the local PostgreSQL used by the `postgres` MCP server.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

if ! command -v pg_ctlcluster >/dev/null 2>&1; then
  echo "[session-start] PostgreSQL not installed; skipping DB startup" >&2
  exit 0
fi

PG_VERSION="$(ls /usr/lib/postgresql | sort -n | tail -1)"
if ! pg_ctlcluster "$PG_VERSION" main status >/dev/null 2>&1; then
  pg_ctlcluster "$PG_VERSION" main start
fi

for _ in $(seq 1 30); do
  pg_isready -q -h localhost -p 5432 && break
  sleep 1
done

# Local throwaway dev password; matches the DATABASE_URI fallback in .mcp.json.
su postgres -c "psql -qc \"ALTER USER postgres PASSWORD 'postgres';\""

# Warm the uv cache so the MCP server starts quickly.
uvx --with 'mcp<2' postgres-mcp==0.3.0 --help >/dev/null 2>&1 || true
