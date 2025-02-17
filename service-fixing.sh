#!/bin/bash

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_USER_ID" \
        -d text="$message" \
        -d parse_mode="Markdown"
}

# Fungsi untuk memeriksa status service
check_service() {
    local service_name="$1"
    local service_display_name="$2"
    local status=$(systemctl is-active "$service_name")

    if [ "$status" != "active" ]; then
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        local error_message="━━━━━━━━━━━━━
🔴 Server Monitoring | @fernandairfan
 ━━━━━━━━━━━━━
Domain : $DOMAIN
Status Down : $service_display_name🔴
Waktu Down : $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$error_message"

        systemctl restart "$service_name"

        local restart_message="━━━━━━━━━━━━━
✅ Server Monitoring | @fernandairfan
 ━━━━━━━━━━━━━
Domain : $DOMAIN
Restart : $service_display_name✅
Waktu Restart : $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$restart_message"

        echo "[ERROR] $current_time - $service_display_name is down and has been restarted." >> /var/log/service-fixing.log
    else
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $service_display_name is running normally." >> /var/log/service-fixing.log
    fi
}

# Meminta input dari pengguna
read -p "Masukkan ID User Telegram: " TELEGRAM_USER_ID
read -p "Masukkan Token Bot Telegram: " TELEGRAM_BOT_TOKEN
read -p "Masukkan Domain: " DOMAIN

# Menyimpan data ke file konfigurasi
echo "TELEGRAM_USER_ID=$TELEGRAM_USER_ID" > /etc/service-fixing.conf
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> /etc/service-fixing.conf
echo "DOMAIN=$DOMAIN" >> /etc/service-fixing.conf

# Mengirim notifikasi bahwa server fixing sedang berjalan
send_telegram_notification "Server Fixing is running..."

echo "Server Fixing is running..."

# Loop untuk memeriksa service setiap 5 detik
while true; do
    check_service "paradis" "vmess"
    check_service "sketsa" "vless"
    check_service "drawit" "trojan"
    sleep 5
done