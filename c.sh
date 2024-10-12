#!/bin/bash

# Cloudflare API details
auth_email="YourEmail"                     # Your Cloudflare email
auth_key="YourGlobalAPI"                   # Your Global API Key
zone_identifier="YourZondID"               # Zone ID for your domain
record_name="YourRecord"                   # DNS record to update
ttl=3600                                   # DNS TTL (in seconds)
proxy="false"                              # Whether the Cloudflare proxy is enabled (true/false)

# Check IP detection function
detect_public_ip() {
    curl -s https://api.ipify.org
}

# Function to update DNS record
update_dns_record() {
    local new_ip="$1"
    local record_identifier="$2"

    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
        -H "X-Auth-Email: $auth_email" \
        -H "X-Auth-Key: $auth_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$new_ip\",\"ttl\":$ttl,\"proxied\":${proxy}}")

    if [[ $update == *"\"success\":true"* ]]; then
        echo "Cloudflare DNS record updated successfully: $new_ip"
    else
        echo "Failed to update Cloudflare DNS. Response: $update"
        exit 1
    fi
}

# Function to check if an update is needed
check_and_update_ip() {
    # Get current public IP
    new_ip=$(detect_public_ip)

    if [[ ! $new_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Failed to detect a valid public IP. Exiting."
        exit 1
    fi

    echo "Detected Public IP: $new_ip"

    # Get the DNS record info from Cloudflare
    record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
        -H "X-Auth-Email: $auth_email" \
        -H "X-Auth-Key: $auth_key" \
        -H "Content-Type: application/json")

    if [[ $record == *"\"success\":false"* ]]; then
        echo "Failed to fetch DNS record from Cloudflare. Response: $record"
        exit 1
    fi

    # Extract the current Cloudflare IP
    current_ip=$(echo "$record" | grep -oP '(?<="content":")[^"]+')
    record_identifier=$(echo "$record" | grep -oP '(?<="id":")[^"]+')

    echo "Current Cloudflare DNS IP: $current_ip"

    # Compare the current IP with the detected public IP
    if [[ "$new_ip" == "$current_ip" ]]; then
        echo "IP has not changed. No update needed."
    else
        echo "IP has changed. Updating DNS record..."
        update_dns_record "$new_ip" "$record_identifier"
    fi
}

# Main loop to check for IP change every 5 minutes (adjust as needed)
while true; do
    check_and_update_ip
    sleep 300  # Wait for 5 minutes before checking again
done

