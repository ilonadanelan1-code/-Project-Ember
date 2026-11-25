#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

REPO="ilonadanelan1-code/-Project-Ember"
BRANCH="qa/godot-4.7.2-visual-pipeline-v0.17.1"
ZIP_NAME="Project-Ember-v0.17.1-Godot-QA-Pipeline.zip"
ZIP_PATH="${1:-$HOME/storage/downloads/$ZIP_NAME}"

if [[ ! -d "$HOME/storage/downloads" ]] && command -v termux-setup-storage >/dev/null 2>&1; then
  termux-setup-storage
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Не найден архив: $ZIP_PATH"
  echo "Сначала скачай $ZIP_NAME в папку Downloads Android."
  echo "Можно передать путь к ZIP аргументом: bash $0 /путь/к/архиву.zip"
  exit 2
fi

pkg install -y git gh unzip

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo
  echo "Нужна авторизация GitHub. Сейчас откроется одноразовая авторизация устройства."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git

WORK_DIR="$(mktemp -d "$HOME/ember-qa-publish.XXXXXX")"
TEMP_DIR="$(mktemp -d "$HOME/ember-qa-archive.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Клонирую подключённый репозиторий..."
git clone --filter=blob:none "https://github.com/$REPO.git" "$WORK_DIR/repo"
cd "$WORK_DIR/repo"
git fetch origin main
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  echo "Ветка $BRANCH уже существует. Скрипт остановлен, чтобы не перезаписывать её."
  exit 3
fi
git switch -c "$BRANCH" origin/main

echo "Распаковываю Project Ember v0.17.1..."
unzip -q "$ZIP_PATH" -d "$TEMP_DIR"
PROJECT_FILE="$(find "$TEMP_DIR" -mindepth 2 -maxdepth 4 -type f -name project.godot -print -quit)"
if [[ -z "$PROJECT_FILE" ]]; then
  echo "В ZIP не найден project.godot" >&2
  exit 4
fi
SOURCE_DIR="$(dirname "$PROJECT_FILE")"
if [[ ! -f "$SOURCE_DIR/.github/workflows/ember-qa.yml" ]]; then
  echo "В архиве отсутствует .github/workflows/ember-qa.yml" >&2
  exit 5
fi

rm -rf project_ember
mkdir -p project_ember
cp -a "$SOURCE_DIR/." project_ember/
mkdir -p .github/workflows
cp project_ember/.github/workflows/ember-qa.yml .github/workflows/ember-qa.yml

cat > README.md <<'README'
# Project Ember

Current source release: **v0.17.1 — Godot 4.7.2 QA Pipeline**.

- [Project design](project_ember/DESIGN.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [QA pipeline](project_ember/tools/qa/README.md)

The QA workflow pins the official Godot 4.7.2 editor binary, verifies its SHA-256, imports all resources, runs all GDScript smoke tests, and captures the strategic map at four zoom levels. Screenshots, render metrics and logs are uploaded as a GitHub Actions artifact. Android GPU performance still requires a physical-device report.

This is a Godot source project, not an APK.
README

git config user.name "Project Ember QA"
git config user.email "264723884+ilonadanelan1-code@users.noreply.github.com"
git add -A project_ember .github/workflows/ember-qa.yml README.md
git commit -m "Add Project Ember v0.17.1 and Godot 4.7.2 visual QA pipeline"
echo "Отправляю отдельную QA-ветку. main не изменяется..."
git push -u origin "$BRANCH"

echo "Создаю Pull Request..."
PR_URL="$(gh pr create --repo "$REPO" --base main --head "$BRANCH" \
  --title "Project Ember v0.17.1 — Godot 4.7.2 Visual QA Pipeline" \
  --body "Publishes the v0.17.1 source project on a dedicated QA branch. Adds checksum-pinned Godot 4.7.2 import, 18 smoke tests, four-scale screenshot capture, and QA artifact upload. Does not modify main or the existing PR #4.")"

echo
 echo "Готово. QA Pull Request: $PR_URL"
echo "Рабочая копия: $WORK_DIR/repo"
echo "После открытия PR GitHub Actions запустит Godot 4.7.2 и приложит QA-архив со скриншотами и логами."
