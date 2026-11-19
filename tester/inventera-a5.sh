#!/bin/bash

# Inventering inför krav A5
# Samlar manifest och beroenden utan att exponera hemligheter.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFESTS="$ROOT/manifests"
OUTPUT="$ROOT/tester/bevis/A5-inventering.txt"

mkdir -p "$ROOT/tester/bevis"

{
    echo "A5 – INVENTERING AV MANIFEST OCH BEROENDEN"
    echo "Datum: $(date)"
    echo

    echo "===== MANIFESTFILER ====="
    find "$MANIFESTS" -maxdepth 1 -type f -name '*.yaml' -printf '%f\n' | sort
    echo

    for file in \
        wall-configmap.yaml \
        wall-pvc.yaml \
        wall-db-service.yaml \
        wall-web-service.yaml \
        wall-db-networkpolicy.yaml \
        wall-route.yaml \
        wall-db-deployment.yaml \
        wall-web-deployment.yaml \
        wall-web-hpa.yaml
    do
        echo "===== $file ====="
        if [[ -f "$MANIFESTS/$file" ]]; then
            cat "$MANIFESTS/$file"
        else
            echo "SAKNAS: $file"
        fi
        echo
    done

    echo "===== SECRET ====="
    if [[ -f "$MANIFESTS/wall-secret.yaml" ]]; then
        echo "wall-secret.yaml finns."
        echo "Innehållet visas inte av säkerhetsskäl."
    else
        echo "SAKNAS: wall-secret.yaml"
    fi

    echo
    echo "===== CONTAINER IMAGE ====="
    grep -nE '^[[:space:]]*image:' "$MANIFESTS"/*deployment.yaml 2>/dev/null || true

} > "$OUTPUT"

echo "Inventering klar: $OUTPUT"

