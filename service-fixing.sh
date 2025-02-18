#!/bin/bash

# Konfigurasi
LOG_FILE="/var/log/service-fixing.log"
MAX_LOG_SIZE=1048576  # 1MB
NOTIFICATION_FLAG="/etc/service-fixing.notified"
CONFIG_FILE="/etc/service-fixing.conf"

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d message_thread_id="$TELEGRAM_TOPIC_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" || echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - Failed to send Telegram notification." >> "$LOG_FILE"
}

# Fungsi membersihkan log jika melebihi ukuran maksimal
clean_log() {
    if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - Log file exceeded max size, cleaning..." > "$LOG_FILE"
    fi
}

# Fungsi memeriksa status service
check_service() {
    local service_name="$1"
    local service_display_name="$2"
    local status=$(systemctl is-active "$service_name")
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$status" != "active" ]; then
        local error_message="━━━━━━━━━━━━━
*🔴 Server Monitoring*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Status Down :* $service_display_name 🔴
*⤿ Waktu Down :* $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$error_message"
        systemctl restart "$service_name" || echo "[ERROR] $current_time - Failed to restart $service_display_name." >> "$LOG_FILE"

        local restart_message="━━━━━━━━━━━━━
*✅ Server Monitoring*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Restart :* $service_display_name ✅
*⤿ Waktu Restart :* $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$restart_message"
        echo "[INFO] $current_time - $service_display_name restarted." >> "$LOG_FILE"
    else
        echo "[INFO] $current_time - $service_display_name is running normally." >> "$LOG_FILE"
    fi
}

# Fungsi untuk membuat systemd service
create_systemd_service() {
    local service_file="/etc/systemd/system/service-fixing.service"
    cat <<EOF > "$service_file"
[Unit]
Description=Service Fixing Script
After=network.target

[Service]
ExecStart=/usr/local/bin/service-fixing.sh
Restart=always
User=root
EnvironmentFile=/etc/service-fixing.conf

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable service-fixing.service
    systemctl start service-fixing.service
    systemctl status service-fixing.service
}

# Fungsi memuat konfigurasi
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "Konfigurasi tidak ditemukan. Harap jalankan setup terlebih dahulu: sudo /usr/local/bin/service-fixing.sh setup"
        exit 1
    fi
}

# Fungsi setup awal
setup_config() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "⟨⟨ BOT NOTIFICATION ⟩⟩"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Group Chat"
    echo "2. Group Topik"
    echo "3. BOT Private"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    read -p "Pilih opsi [1-3]: " choice

    case $choice in
        1)
            echo "Anda memilih Group Chat"
            read -p "Masukkan Group ID: " TELEGRAM_CHAT_ID
            TELEGRAM_TOPIC_ID=""
            ;;
        2)
            echo "Anda memilih Group Topik"
            read -p "Masukkan Group ID: " TELEGRAM_CHAT_ID
            read -p "Masukkan Topic ID: " TELEGRAM_TOPIC_ID
            ;;
        3)
            echo "Anda memilih BOT Private"
            read -p "Masukkan User ID: " TELEGRAM_CHAT_ID
            TELEGRAM_TOPIC_ID=""
            ;;
        *)
            echo "Pilihan tidak valid"
            exit 1
            ;;
    esac

    read -p "Masukkan Token Bot Telegram: " TELEGRAM_BOT_TOKEN
    read -p "Masukkan Domain: " DOMAIN

    # Simpan konfigurasi
    cat <<EOF > "$CONFIG_FILE"
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
TELEGRAM_TOPIC_ID=$TELEGRAM_TOPIC_ID
DOMAIN=$DOMAIN
EOF

    echo "Konfigurasi berhasil disimpan di $CONFIG_FILE"
}

# Fungsi utama
main() {
    # Jika mode setup dipilih
    if [[ "$1" == "setup" ]]; then
        setup_config
        exit 0
    fi

    # Muat konfigurasi
    load_config

    # Kirim notifikasi jika pertama kali dijalankan
    if [[ ! -f "$NOTIFICATION_FLAG" ]]; then
        send_telegram_notification "━━━━━━━━━━━━━
*✅ Server Monitoring*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Status :* Script started successfully!
*⤿ Waktu :* $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━"
        touch "$NOTIFICATION_FLAG"
    fi

    echo "Server Fixing is running..."

    while true; do
        clean_log
        check_service "paradis" "vmess"
        check_service "sketsa" "vless"
        check_service "drawit" "trojan"
        sleep 60
    done
}

# Jalankan fungsi utama
main "$@"
