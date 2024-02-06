#!/bin/bash



API_HOST="<prismcloud-api-host>"
AUTH_TOKEN="<prismacloud-temp-token>"

API_ENDPOINT="$API_HOST/appid/api/v1/satellite"

# Check if clusterAssetId is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <clusterAssetId>"
  exit 1
fi

CLUSTER_ASSET_ID="$1"

# Call cluster onbaording API with required config
# Sample request with http_proxy configured
#{"clusterAssetId":"cluster-asset-id", // eg. cluster ARN for EKS
#    "config":{
#        "proxy_url":"https://internet-proxy.com",
#        "proxy_username":"wqe",
#        "proxy_password":"qwe"
#    }
#}

EPOCH=$(date +%s)
# Initialize temporary file for response body
RESPONSE_BODY=$(mktemp)
touch install_script-${EPOCH}.sh
INSTALL_SCRIPT_FILE=install_script-${EPOCH}.sh # Create a temporary file with a prefix "install_script."


# Post Cluster Details and capture the HTTP status code
HTTP_STATUS=$(curl -s -o "$RESPONSE_BODY" -w "%{http_code}" -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-redlock-auth: $AUTH_TOKEN" \
  --data-raw "{\"clusterAssetId\":\"$CLUSTER_ASSET_ID\",\"config\":{}}")

# Check if the request was successful
if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "Request successful. HTTP Status: $HTTP_STATUS"
else
  echo "Request failed. HTTP Status: $HTTP_STATUS"
  cat "$RESPONSE_BODY"  # Optionally print the response body for debugging
  rm "$RESPONSE_BODY"   # Clean up temporary file
  exit 1
fi

# Parse and sanitize the install script from the response
INSTALL_SCRIPT=$(cat "$RESPONSE_BODY" | jq -r '.installScript')
SANITIZED_SCRIPT=$(echo "$INSTALL_SCRIPT" | sed 's/\\n/\n/g')
echo $SANITIZED_SCRIPT

# Save the sanitized script to a temporary file and make it executable
echo "$SANITIZED_SCRIPT" > "$INSTALL_SCRIPT_FILE"
chmod +x "$INSTALL_SCRIPT_FILE"

# Clean up temporary response body file
rm "$RESPONSE_BODY"

# Execute the install script
./"$INSTALL_SCRIPT_FILE"

# Optionally, remove the install script file after execution if no longer needed
# rm "$INSTALL_SCRIPT_FILE"
