#!/bin/bash

# ==============================================================================
# Rook-Ceph RGW S3 Tester using curl
#
# Author: AI Assistant
# Version: 1.0
#
# This script tests the S3 object storage by uploading, listing,
# and downloading a file using only kubectl and curl.
# It should be run on a node that has kubectl access to the cluster.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# The name of the ObjectBucketClaim in your default namespace.
OBC_NAME="my-bucket"
# The namespace where the OBC is located.
OBC_NAMESPACE="default"

# --- Color Definitions ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Helper Functions ---
function print_info() {
    echo -e "${C_BLUE}INFO: $1${C_RESET}"
}
function print_success() {
    echo -e "${C_GREEN}SUCCESS: $1${C_RESET}"
}
function print_warning() {
    echo -e "${C_YELLOW}WARNING: $1${C_RESET}"
}
function print_error() {
    echo -e "${C_RED}ERROR: $1${C_RESET}" >&2
    exit 1
}
function check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Command '$1' not found. This script requires kubectl, curl, and openssl."
    fi
}

# --- Main Logic ---
check_command "kubectl"
check_command "curl"
check_command "openssl"

# --- Step 1: Extract credentials and endpoint ---
print_info "Step 1: Extracting S3 credentials and endpoint..."
RGW_SERVICE_IP=$(kubectl -n rook-ceph get svc rook-ceph-rgw-my-store -o jsonpath='{.spec.clusterIP}')
if [ -z "$RGW_SERVICE_IP" ]; then
    print_error "Could not find the RGW service ClusterIP. Is the CephObjectStore 'my-store' ready?"
fi

AWS_HOST="$RGW_SERVICE_IP"
AWS_ACCESS_KEY_ID=$(kubectl -n "$OBC_NAMESPACE" get secret "$OBC_NAME" -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 --decode)
AWS_SECRET_ACCESS_KEY=$(kubectl -n "$OBC_NAMESPACE" get secret "$OBC_NAME" -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 --decode)
BUCKET_NAME=$(kubectl -n "$OBC_NAMESPACE" get cm "$OBC_NAME" -o jsonpath='{.data.BUCKET_NAME}')

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$BUCKET_NAME" ]; then
    print_error "Failed to get all required credentials from Secret/ConfigMap '${OBC_NAME}' in namespace '${OBC_NAMESPACE}'."
fi
print_success "Credentials and endpoint extracted successfully."
echo "  - Host/IP: ${C_CYAN}$AWS_HOST${C_RESET}"
echo "  - Bucket:  ${C_CYAN}$BUCKET_NAME${C_RESET}"
echo

# --- Step 2: Create a local test file ---
print_info "Step 2: Creating a local test file..."
TEST_FILE="/tmp/s3_curl_test_file.txt"
TEST_CONTENT="Hello Rook S3, test executed at $(date)"
echo "$TEST_CONTENT" > "$TEST_FILE"
print_success "Test file created at ${C_CYAN}$TEST_FILE${C_RESET}"
echo

# --- Step 3: Upload the file (PUT) ---
print_info "Step 3: Uploading the file to S3..."
OBJECT_KEY="test-upload-$(date +%s).txt"
RESOURCE="/${BUCKET_NAME}/${OBJECT_KEY}"
CONTENT_TYPE="text/plain"
DATE_HEADER=$(date -R)
STRING_TO_SIGN="PUT\n\n${CONTENT_TYPE}\n${DATE_HEADER}\n${RESOURCE}"
SIGNATURE=$(echo -en "${STRING_TO_SIGN}" | openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary | base64)

HTTP_STATUS=$(curl --write-out "%{http_code}" --silent --output /dev/null -X PUT -T "${TEST_FILE}" \
  -H "Host: ${AWS_HOST}" \
  -H "Date: ${DATE_HEADER}" \
  -H "Content-Type: ${CONTENT_TYPE}" \
  -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${SIGNATURE}" \
  "http://${AWS_HOST}${RESOURCE}")

if [ "$HTTP_STATUS" -eq 200 ]; then
    print_success "File uploaded successfully (HTTP Status: 200 OK)."
else
    print_error "File upload failed! (HTTP Status: $HTTP_STATUS)"
fi
echo

# --- Step 4: List objects in the bucket (GET) ---
print_info "Step 4: Listing objects in the bucket..."
RESOURCE="/${BUCKET_NAME}/"
DATE_HEADER=$(date -R)
STRING_TO_SIGN="GET\n\n\n${DATE_HEADER}\n${RESOURCE}"
SIGNATURE=$(echo -en "${STRING_TO_SIGN}" | openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary | base64)

curl -s -X GET \
  -H "Host: ${AWS_HOST}" \
  -H "Date: ${DATE_HEADER}" \
  -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${SIGNATURE}" \
  "http://${AWS_HOST}${RESOURCE}" | grep "<Key>${OBJECT_KEY}</Key>" > /dev/null

if [ $? -eq 0 ]; then
    print_success "Successfully found the uploaded object '${OBJECT_KEY}' in the bucket list."
else
    print_error "Could not find the uploaded object in the bucket list."
fi
echo

# --- Step 5: Download the file and verify (GET) ---
print_info "Step 5: Downloading the file for verification..."
DOWNLOADED_FILE="/tmp/s3_downloaded_file.txt"
RESOURCE="/${BUCKET_NAME}/${OBJECT_KEY}"
DATE_HEADER=$(date -R)
STRING_TO_SIGN="GET\n\n\n${DATE_HEADER}\n${RESOURCE}"
SIGNATURE=$(echo -en "${STRING_TO_SIGN}" | openssl sha1 -hmac "${AWS_SECRET_ACCESS_KEY}" -binary | base64)

curl -s -X GET -o "$DOWNLOADED_FILE" \
  -H "Host: ${AWS_HOST}" \
  -H "Date: ${DATE_HEADER}" \
  -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${SIGNATURE}" \
  "http://${AWS_HOST}${RESOURCE}"

print_success "File downloaded to ${C_CYAN}$DOWNLOADED_FILE${C_RESET}"

print_info "Verifying content..."
DOWNLOADED_CONTENT=$(cat "$DOWNLOADED_FILE")
if [ "$DOWNLOADED_CONTENT" == "$TEST_CONTENT" ]; then
    print_success "Verification successful! Content matches."
else
    print_error "Verification FAILED! Content does not match."
    echo "Expected: $TEST_CONTENT"
    echo "Got: $DOWNLOADED_CONTENT"
fi
echo

# --- Step 6: Clean up ---
print_info "Step 6: Cleaning up local test files..."
rm -f "$TEST_FILE" "$DOWNLOADED_FILE"
print_success "Cleanup complete."
echo

print_success "==================== S3 Test Finished Successfully ===================="
