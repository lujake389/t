#!/bin/bash

# Cloudflare API details
auth_email="sydjwd92@gmail.com"                     # Your Cloudflare email
auth_key="ab1ca6a961ce2fb2b4f1301f70e9afccdf05c"    # Your Global API Key
zone_identifier="f2a8fae655d97d06580123f16a7cb7b9"  # Zone ID for your domain
record_name="yyy.inters.site"                       # DNS record to update
ttl=3600                                            # DNS TTL (in seconds)
proxy="false"                                       # Whether the Cloudflare proxy is enabled (true/false)

# Telegram bot details
CHATID="5747562905"
KEY="7422462630:AAEYpTcELKBDiKwztS6F1g9C_TD8HHYmHKM"
URL="https://api.telegram.org/bot$KEY/sendMessage"

# Function to detect public IP
detect_public_ip() {
    curl -s https://api.ipify.org
}

# Function to send notification to Telegram
send_telegram_notification() {
    local new_ip="$1"
    local current_ip="$2"
    local message="
    <code>━━━━━━━━━━━━━━━━━━━━━━━━━</code>
    <b>Cloudflare DDNS Update</b>
    <code>━━━━━━━━━━━━━━━━━━━━━━━━━</code>
    <code>Domain   :</code><code>$record_name</code>
    <code>Old IP   :</code><code>$current_ip</code>
    <code>New IP   :</code><code>$new_ip</code>
    <code>━━━━━━━━━━━━━━━━━━━━━━━━━</code>
    <i>IP address successfully updated on Cloudflare.</i>"

    curl -s --max-time 10 -d "chat_id=$CHATID&disable_web_page_preview=1&text=$message&parse_mode=html" $URL >/dev/null
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
        # Send Telegram notification
        send_telegram_notification "$new_ip" "$current_ip"
    fi
}

# Main loop to check for IP change every 5 minutes (adjust as needed)
while true; do
    check_and_update_ip
    sleep 60 # Wait for 5 minutes before checking again 
done
