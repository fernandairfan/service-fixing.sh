#!/bin/bash

# Konfigurasi file log
LOG_FILE="/var/log/service-fixing.log"
MAX_LOG_SIZE=1048576  # 1MB (dalam bytes)
NOTIFICATION_FLAG="/etc/service-fixing.notified"  # File penanda notifikasi
CONFIG_FILE="/etc/service-fixing.conf"

# Fungsi untuk mengirim notifikasi ke Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown"
}

# Fungsi untuk membersihkan log jika melebihi ukuran maksimal
clean_log() {
    if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - Log file exceeded maximum size, cleaning up..." > "$LOG_FILE"
    fi
}

# Fungsi untuk memeriksa status service
check_service() {
    local service_name="$1"
    local service_display_name="$2"
    local status=$(systemctl is-active "$service_name")
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')  # Timestamp untuk setiap pengecekan

    if [ "$status" != "active" ]; then
        local error_message="━━━━━━━━━━━━━
*🔴 Server Monitoring | @fernandairfan*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Status Down :* $service_display_name 🔴
*⤿ Waktu Down :* $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$error_message"

        systemctl restart "$service_name"

        local restart_message="━━━━━━━━━━━━━
*✅ Server Monitoring | @fernandairfan*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Restart :* $service_display_name ✅
*⤿ Waktu Restart :* $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$restart_message"

        echo "[ERROR] $current_time - $service_display_name is down and has been restarted." >> "$LOG_FILE"
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
Environment="TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
Environment="TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID"
Environment="TELEGRAM_TOPIC_ID=$TELEGRAM_TOPIC_ID"
Environment="DOMAIN=$DOMAIN"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl start service-fixing.service
    systemctl enable service-fixing.service
}

# Fungsi untuk menampilkan menu pilihan
show_menu() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "⟨⟨ BOT NOTIFICATION ⟩⟩"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Group Chat"
    echo "2. Group Topik"
    echo "3. BOT Private"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    read -p "Select [1-3]: " choice

    case $choice in
        1)
            echo "Anda memilih Group Chat"
            read -p "Masukkan Group ID: " TELEGRAM_CHAT_ID
            ;;
        2)
            echo "Anda memilih Group Topik"
            read -p "Masukkan Group ID: " TELEGRAM_CHAT_ID
            read -p "Masukkan Topic ID: " TELEGRAM_TOPIC_ID
            ;;
        3)
            echo "Anda memilih BOT Private"
            read -p "Masukkan User ID: " TELEGRAM_CHAT_ID
            ;;
        *)
            echo "Pilihan tidak valid"
            exit 1
            ;;
    esac
}

# Fungsi utama untuk menjalankan script
main() {
    # Tampilkan menu pilihan segera setelah script dijalankan
    show_menu

    # Meminta input dari pengguna
    while [[ -z "$TELEGRAM_BOT_TOKEN" ]]; do
        read -p "Masukkan Token Bot Telegram: " TELEGRAM_BOT_TOKEN
    done

    while [[ -z "$DOMAIN" ]]; do
        read -p "Masukkan Domain: " DOMAIN
    done

    # Menyimpan data ke file konfigurasi
    echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" > "$CONFIG_FILE"
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> "$CONFIG_FILE"
    echo "TELEGRAM_TOPIC_ID=$TELEGRAM_TOPIC_ID" >> "$CONFIG_FILE"
    echo "DOMAIN=$DOMAIN" >> "$CONFIG_FILE"

    # Membuat systemd service
    create_systemd_service

    # Mengirim notifikasi bahwa server fixing sedang berjalan (hanya sekali)
    if [[ ! -f "$NOTIFICATION_FLAG" ]]; then
        send_telegram_notification "━━━━━━━━━━━━━
*✅ Server Monitoring | @fernandairfan*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Status :* Script started successfully!
*⤿ Waktu :* $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━"

        # Buat file penanda
        touch "$NOTIFICATION_FLAG"
    fi

    echo "Server Fixing is running..."

    # Jalankan proses pengecekan service di latar belakang
    (
        while true; do
            clean_log  # Bersihkan log jika melebihi ukuran maksimal
            check_service "paradis" "vmess"
            check_service "sketsa" "vless"
            check_service "drawit" "trojan"
            sleep 60  # Pengecekan setiap 1 menit
        done
    ) &

    echo "Sukses! Script berjalan di latar belakang."
    echo "Log pengecekan disimpan di: $LOG_FILE"
}

# Jalankan fungsi utama
main
