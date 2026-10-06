#!/bin/bash
set -euo pipefail

# Secret Scanning Script
# Scans files in the git repository to ensure no credentials, keys, or secrets are exposed.

echo "=========================================================="
echo "RUNNING SRE SECURITY SCAN: Hardcoded Secrets & Credentials"
echo "=========================================================="

FAILED=0

# 1. AWS Access Key IDs
if grep -rnE "AKIA[0-9A-Z]{16}" . --exclude-dir=.git --exclude-dir=scripts --exclude-dir=jenkins; then
  echo "[-] VIOLATION: Potential AWS Access Key ID detected!"
  FAILED=1
fi

# 2. Private Keys
if grep -rnE "BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY" . --exclude-dir=.git --exclude-dir=scripts --exclude-dir=jenkins; then
  echo "[-] VIOLATION: Unencrypted private key found!"
  FAILED=1
fi

# 3. AWS Secret Access Keys regex
if grep -rnE "aws_secret_access_key\s*=\s*['\"][A-Za-z0-9/+=]{40}['\"]" . --exclude-dir=.git --exclude-dir=scripts --exclude-dir=jenkins; then
  echo "[-] VIOLATION: Plaintext AWS Secret Access Key detected!"
  FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then
  echo "[+] SUCCESS: No credentials or secrets found in codebase."
else
  echo "[-] FAILED: Security scan failed."
  exit 1
fi
