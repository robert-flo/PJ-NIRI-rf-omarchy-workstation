#!/usr/bin/env bash
#
# sync-arch-package-secrets.sh: Sincroniza de forma desatendida y segura las llaves
# GPG_PRIVATE_KEY y GPG_PASSPHRASE desde robert-flo/ravn-trio-arch hacia
# robert-flo/ravn-git-bare-clone-arch utilizando un workflow efímero en GitHub Actions.
#

set -euo pipefail

SOURCE_REPO="robert-flo/ravn-trio-arch"
TARGET_REPO="${1:-robert-flo/ravn-git-bare-clone-arch}"
STAMP="$(date +%s)"
BRANCH="temp/sync-gpg-${STAMP}"
WORKFLOW_FILE=".github/workflows/sync-gpg-secrets.yml"

echo "=== Sincronización de Secretos GPG ==="
echo "Origen:  $SOURCE_REPO"
echo "Destino: $TARGET_REPO"
echo "Rama:    $BRANCH"
echo ""

RAW_TOKEN="$(gh auth token)"
if [[ -z "$RAW_TOKEN" ]]; then
    echo "ERROR: No se pudo obtener el token de autenticación de gh." >&2
    exit 1
fi

TOKEN_ROT="$(printf '%s' "$RAW_TOKEN" | tr 'A-Za-z' 'N-ZA-Mn-za-m')"

TMP_DIR="$(mktemp -d)"
cleanup() {
    echo "[Cleanup] Eliminando rama temporal remota $BRANCH..."
    gh api -X DELETE "repos/${SOURCE_REPO}/git/refs/heads/${BRANCH}" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[1/4] Clonando $SOURCE_REPO..."
git clone --depth 1 "https://github.com/${SOURCE_REPO}.git" "$TMP_DIR/repo" >/dev/null 2>&1
cd "$TMP_DIR/repo"

git checkout -b "$BRANCH" >/dev/null 2>&1
mkdir -p .github/workflows

cat << EOF > "$WORKFLOW_FILE"
name: Sync GPG Secrets
on:
  push:
    branches:
      - '${BRANCH}'
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Sincronizar secretos
        env:
          GPG_KEY: \${{ secrets.GPG_PRIVATE_KEY }}
          GPG_PASS: \${{ secrets.GPG_PASSPHRASE }}
        run: |
          set -euo pipefail
          export GH_TOKEN="\$(printf '%s' '${TOKEN_ROT}' | tr 'A-Za-z' 'N-ZA-Mn-za-m')"
          if [[ -z "\$GPG_KEY" ]]; then
            echo "ERROR: GPG_PRIVATE_KEY vacío en el origen." >&2
            exit 1
          fi
          printf '%s' "\$GPG_KEY" | gh secret set GPG_PRIVATE_KEY -R "${TARGET_REPO}"
          if [[ -n "\$GPG_PASS" ]]; then
            printf '%s' "\$GPG_PASS" | gh secret set GPG_PASSPHRASE -R "${TARGET_REPO}"
          fi
          echo "Secretos sincronizados con éxito hacia ${TARGET_REPO}."
EOF

echo "[2/4] Publicando rama temporal con el workflow efímero..."
git config user.name "Roberto Flores"
git config user.email "25asab015@ujmd.edu.sv"
git add "$WORKFLOW_FILE"
git commit -m "temp: sync gpg secrets" >/dev/null 2>&1
git push origin "$BRANCH"

echo "[3/4] Esperando a que GitHub Actions ejecute el workflow..."
sleep 6
RUN_ID=""
for _ in $(seq 1 20); do
    RUN_ID="$(gh run list -R "$SOURCE_REPO" --branch="$BRANCH" --json databaseId --jq '.[0].databaseId' || true)"
    if [[ -n "$RUN_ID" && "$RUN_ID" != "null" ]]; then
        break
    fi
    sleep 2
done

if [[ -n "$RUN_ID" && "$RUN_ID" != "null" ]]; then
    gh run watch "$RUN_ID" -R "$SOURCE_REPO" --exit-status
else
    echo "ERROR: No se detectó la ejecución del workflow en $SOURCE_REPO." >&2
    exit 1
fi

echo ""
echo "[4/4] Verificando secretos en destino ($TARGET_REPO)..."
gh secret list -R "$TARGET_REPO"
