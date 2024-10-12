#!/bin/bash

# Cloudflare & Telegram bot setup
TIMES="10"
CHATID="5747562905"
KEY="7422462630:AAEYpTcELKBDiKwztS6F1g9C_TD8HHYmHKM"
URL="https://api.telegram.org/bot$KEY/sendMessage"

# Function to display the menu and collect Cloudflare details
function show_menu() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      Cloudflare DDNS     "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "     Script by javakeisha "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"

    read -p "Enter your Cloudflare Email: " auth_email
    read -p "Enter your Global API Key: " auth_key
    read -p "Enter your Zone ID: " zone_identifier
    read -p "Enter DNS record to update (e.g., example.com): " record_name
    read -p "Enable proxy (true/false): " proxy

    # Set default TTL if not provided
    ttl=3600
    echo "Using default TTL: $ttl seconds"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "        Processing...     "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"

    add_cron_job
}

# Function to add cron job
function add_cron_job() {
    # Add cron job to check IP every minute
    (crontab -l; echo "* * * * * /root/cf.sh") | crontab -

    echo "Cron job added to check IP every minute."
    echo "Returning to menu..."
    sleep 2  # Wait for 2 seconds before showing the menu again
    show_menu
}

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
        send_telegram_notification "$new_ip" "$current_ip"
    else
        echo "Failed to update Cloudflare DNS. Response: $update"
        exit 1
    fi
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

    curl -s --max-time $TIMES -d "chat_id=$CHATID&disable_web_page_preview=1&text=$message&parse_mode=html" $URL >/dev/null
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

# Main function to run the menu
menu
