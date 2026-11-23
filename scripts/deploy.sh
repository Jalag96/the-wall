#!/bin/bash
set -e

cd "$(dirname "$0")/.."
echo "=== The Wall Deployment ==="

# Kontrollera att Secret redan finns
if ! oc get secret wall-secret >/dev/null 2>&1; then
    echo "FEL: Secret wall-secret saknas."
    echo "Skapa den först enligt README.md."
    exit 1
fi

# Konfiguration och lagring
oc apply -f manifests/wall-configmap.yaml
oc apply -f manifests/wall-pvc.yaml

# Databas och nätverk
oc apply -f manifests/wall-db-service.yaml
oc apply -f manifests/wall-db-networkpolicy.yaml
oc apply -f manifests/wall-db-deployment.yaml

# Webbapplikation
oc apply -f manifests/wall-web-service.yaml
oc apply -f manifests/wall-web-deployment.yaml
oc apply -f manifests/wall-web-hpa.yaml
oc apply -f manifests/wall-route.yaml

echo
echo "=== Deployment submitted ==="
oc get pods

