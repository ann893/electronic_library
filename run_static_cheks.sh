#!/usr/bin/env bash
set -euo pipefail

# === ПАРАМЕТРЫ ===
PY_DIR="app"                # Папка с кодом
PYLINT_FAIL_UNDER=7.0       # Минимальная оценка кода
EXIT_CODE=0                 # Код возврата (в конце, если что-то не прошло)

echo "== НАЧАЛО СТАТИЧЕСКИХ ПРОВЕРОК =="

# ---------- Pylint ----------
echo
echo "-> Запуск Pylint (качество кода)..."
pylint $PY_DIR --exit-zero --score=y > pylint_full.txt || true
PYLINT_SCORE=$(grep "Your code has been rated at" pylint_full.txt | awk '{print $7}' | cut -d'/' -f1)

if [[ -z "$PYLINT_SCORE" ]]; then
  PYLINT_SCORE=0
fi

echo "Pylint score: $PYLINT_SCORE/10"

python3 - <<PY
s=float("$PYLINT_SCORE")
limit=float("$PYLINT_FAIL_UNDER")
if s < limit:
    print("❌ Pylint: рейтинг ниже порога (",s,"<",limit,")")
else:
    print("✅ Pylint: рейтинг нормальный (",s,">=",limit,")")
PY

# Проверка на порог
if (( $(echo "$PYLINT_SCORE < $PYLINT_FAIL_UNDER" | bc -l) )); then
  EXIT_CODE=2
fi

# ---------- Bandit ----------
echo
echo "-> Запуск Bandit (анализ безопасности)..."
bandit -r $PY_DIR -f json -o bandit_report.json || true
python3 - <<'PY'
import json, sys
try:
    data = json.load(open("bandit_report.json"))
except Exception as e:
    print("Ошибка чтения bandit_report.json:", e)
    sys.exit(0)

issues = data.get("results", [])
high = [i for i in issues if i.get("issue_severity", "").upper() in ("HIGH", "CRITICAL")]
if high:
    print("❌ Bandit: найдены HIGH/CRITICAL уязвимости:")
    for h in high:
        print("-", h.get("issue_text", ""), "в", h.get("filename", ""))
    open(".bandit_fail", "w").close()
else:
    print("✅ Bandit: критических уязвимостей не найдено.")
PY

if [[ -f ".bandit_fail" ]]; then
  EXIT_CODE=3
  rm .bandit_fail
fi

# ---------- Trufflehog ----------
echo
echo "-> Запуск Trufflehog (поиск секретов)..."
trufflehog filesystem --directory ./ --json > trufflehog_report.json || true
python3 - <<'PY'
import json, sys
secrets = []
try:
    for line in open("trufflehog_report.json"):
        line=line.strip()
        if not line: continue
        d=json.loads(line)
        if "Raw" in str(d) or "key" in str(d).lower() or "secret" in str(d).lower():
            secrets.append(d)
except Exception as e:
    print("Ошибка при разборе trufflehog:", e)

if secrets:
    print("❌ Trufflehog: найдены возможные секреты (пароли/ключи).")
    open(".truffle_fail","w").close()
else:
    print("✅ Trufflehog: секреты не найдены.")
PY

if [[ -f ".truffle_fail" ]]; then
  EXIT_CODE=4
  rm .truffle_fail
fi

# ---------- РЕЗУЛЬТАТ ----------
echo
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "== ❌ Проверки завершены: найдены ошибки. Код выхода: $EXIT_CODE =="
else
  echo "== ✅ Все проверки пройдены успешно =="
fi

exit $EXIT_CODE
