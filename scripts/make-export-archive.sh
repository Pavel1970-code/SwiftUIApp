#!/bin/bash
# Создаёт ZIP только из файлов, которые уже в Git (без DerivedData, без неотслеживаемого мусора).
# Запуск: из корня репозитория: ./scripts/make-export-archive.sh

set -euo pipefail
cd "$(dirname "$0")/.."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Ошибка: запускайте скрипт из git-репозитория." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Внимание: есть незакоммиченные изменения. В архив попадёт только то, что уже в последнем коммите (git archive)."
  echo "Для полного переноса правок сначала: git add … && git commit && git push"
  read -r -p "Продолжить? [y/N] " ans
  [[ "${ans:-}" =~ ^[yY]$ ]] || exit 1
fi

STAMP=$(date +%Y%m%d-%H%M)
OUT="${TMPDIR:-/tmp}/SwiftUIApp-export-${STAMP}.zip"

git archive --format=zip --prefix="SwiftUIApp/" -o "$OUT" HEAD

echo "Готово: $OUT"
echo "Передайте этот ZIP или дайте ссылку на репозиторий (предпочтительнее git clone)."
