#!/usr/bin/env bash
# anchor_prover.sh — Anchored Receipt v1 (Termux fixed v2)

set -euo pipefail

KMS_SIGN_ENDPOINT="${KMS_SIGN_ENDPOINT:-http://localhost:8201/sign}"
IPFS_PIN_URL="${IPFS_PIN_URL:-http://localhost:6000/pin}"
WORK_DIR="${WORK_DIR:-./anchor_work}"

JQ_BIN="${JQ_BIN:-jq}"
SHA256_BIN="${SHA256_BIN:-sha256sum}"
CURL_BIN="${CURL_BIN:-curl}"

mkdir -p "$WORK_DIR"

selftest() {
    echo "Running selftest..."
    tmp=$(mktemp -d)
    cat > "$tmp/receipt.json" <<JSON
{
  "receipt_id":"rcpt:test:1",
  "issued_at":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "payer":"did:example:alice",
  "payee":"did:example:jmshoopman",
  "line_items":[{"code":"svc:1","desc":"test svc","qty":1,"unit":"svc","amount":10}],
  "total":10,
  "currency":"cryptic-credits",
  "tax":0,
  "status":"issued",
  "anchors": {}
}
JSON

    "$0" submit "$tmp/receipt.json" > "$tmp/out.json" || { echo "❌ Selftest: submit failed"; cat "$tmp/out.json" 2>/dev/null; return 2; }
    jq . "$tmp/out.json" >/dev/null 2>&1 || { echo "❌ Selftest: output invalid JSON"; cat "$tmp/out.json" 2>/dev/null; return 3; }
    echo "✅ Selftest OK; sample output:"
    cat "$tmp/out.json"
    rm -rf "$tmp"
    return 0
}

validate_receipt() {
    local file="$1"
    $JQ_BIN -e '.receipt_id and .issued_at and .payer and .payee and (.line_items | length>0) and .total' "$file" >/dev/null || return 1
}

canonicalize_json() {
    local in="$1"; local out="$2"
    $JQ_BIN -c -S '.' "$in" > "$out"
}

compute_sha256() {
    local in="$1"
    $SHA256_BIN "$in" | awk '{print $1}'
}

pin_to_ipfs() {
    local jsonfile="$1"
    resp=$($CURL_BIN -s -X POST "$IPFS_PIN_URL" -H "Content-Type: application/json" -d @"$jsonfile")
    echo "$resp" | $JQ_BIN -r '.cid' 2>/dev/null || { echo "IPFS Error: $resp" >&2; return 1; }
}

kms_sign_hex() {
    local payload_hex="$1"
    payload_b64=$(printf "%s" "$payload_hex" | xxd -r -p | base64 -w0)
    resp=$($CURL_BIN -s -X POST "$KMS_SIGN_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{\"payloadHex\":\"$payload_hex\",\"payload_b64\":\"$payload_b64\"}")
    sig_hex=$(echo "$resp" | $JQ_BIN -r '.signatureHex // .signature // empty')
    echo "$sig_hex"
}

submit_process() {
    local receipt_file="$1"
    validate_receipt "$receipt_file" || { echo '{"error":"validation_failed"}'; return 1; }

    local canon="${WORK_DIR}/canonical.json"
    canonicalize_json "$receipt_file" "$canon"
    local sha=$(compute_sha256 "$canon")

    ipfs_cid=$(pin_to_ipfs "$canon") || { echo '{"error":"ipfs_pin_failed"}'; return 3; }

    payload_json=$(jq -n \
        --arg rid "$(jq -r .receipt_id "$receipt_file")" \
        --arg sha "sha256:$sha" \
        --arg cid "$ipfs_cid" \
        --arg tot "$(jq -r .total "$receipt_file")" \
        --arg ts "$(jq -r .issued_at "$receipt_file")" \
        '{receipt_id:$rid, sha256:$sha, ipfs_cid:$cid, total:($tot|tonumber), timestamp:$ts}')

    payload_hex=$(printf "%s" "$payload_json" | xxd -p | tr -d '\n' | tr 'a-f' 'A-F')
    sig_hex=$(kms_sign_hex "$payload_hex")

    jq -n \
        --arg receipt_id "$(jq -r .receipt_id "$receipt_file")" \
        --arg sha "sha256:$sha" \
        --arg cid "$ipfs_cid" \
        --arg tx "tx:SIMULATED" \
        --arg sig "$sig_hex" \
        --arg payload_hex "$payload_hex" \
        '{receipt_id:$receipt_id, anchors:{sha256:$sha, ipfs_cid:$cid, blockchain_tx:$tx}, signed:{payload_hex:$payload_hex, signature:$sig}}'
}

if [ "${1:-}" = "--selftest" ]; then
    selftest
    exit $?
fi

case "${1:-}" in
    submit)
        [ -z "${2:-}" ] && { echo "Usage: $0 submit <receipt.json>"; exit 2; }
        submit_process "$2"
        ;;
    *)
        echo "Usage: $0 --selftest | submit <file>"
        exit 2
        ;;
esac
