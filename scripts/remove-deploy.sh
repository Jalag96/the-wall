
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== THE WALL: REMOVE DEPLOYMENT ==="
echo
echo "Detta kommer att:"
echo "- Säkerhetskopiera PostgreSQL-databasen"
echo "- Stoppa webbapplikationen och databasen"
echo "- Ta bort Routes, Services och Deployments"
echo "- Ta bort HPA, NetworkPolicy, ConfigMap och Secret"
echo "- Ta bort PVC:n wall-db-data"
echo
echo "Backup sparas i: $HOME/the-wall/backups/"
echo

read -rp "Vill du fortsätta? Skriv JA: " confirm

if [[ "$confirm" != "JA" ]]; then
    echo "Avbrutet. Inga resurser har ändrats."
    exit 0
fi

echo
echo "=== 1. Skapar databasbackup ==="

./backup-db.sh

echo
echo "=== 2. Stoppar webbapplikationen ==="
oc scale deployment/wall-web --replicas=0

echo
echo "=== 3. Stoppar databasen ==="
oc scale deployment/wall-db --replicas=0

echo
echo "=== 4. Tar bort resurser ==="

oc delete route wall wall-web --ignore-not-found
oc delete hpa wall-web --ignore-not-found
oc delete networkpolicy wall-db-ingress --ignore-not-found
oc delete service wall-web wall-db --ignore-not-found
oc delete deployment wall-web wall-db --ignore-not-found

echo
echo "=== 5. Tar bort PVC och konfiguration ==="

oc delete pvc wall-db-data --ignore-not-found
oc delete configmap wall-configmap --ignore-not-found
oc delete secret wall-secret --ignore-not-found

echo
echo "=== THE WALL REMOVED ==="
echo "Backupen finns kvar i: $HOME/the-wall/backups/"

