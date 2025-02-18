#!/bin/bash

# Konfigurasi
LOG_FILE="/var/log/service-fixing.log"
MAX_LOG_SIZE=1048576  # 1MB
NOTIFICATION_FLAG="/etc/service-fixing.notified"
CONFIG_FILE="/etc/service-fixing.conf"
SERVICE_FILE="/etc/systemd/system/service-fixing.service"

# Fungsi mengirim notifikasi ke Telegram
send_telegram_notification() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d message_thread_id="$TELEGRAM_TOPIC_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" >/dev/null 2>&1
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
        # Cek apakah service benar-benar dalam keadaan error (failed)
        local is_failed=$(systemctl is-failed "$service_name")
        if [ "$is_failed" == "failed" ]; then
            local error_message="━━━━━━━━━━━━━
*🔴 Server Monitoring*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Status Down :* $service_display_name 🔴
*⤿ Waktu Down :* $current_time
━━━━━━━━━━━━━"

            send_telegram_notification "$error_message"
            systemctl restart "$service_name"

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
            echo "[INFO] $current_time - $service_display_name is not active but not in failed state. No action taken." >> "$LOG_FILE"
        fi
    else
        echo "[INFO] $current_time - $service_display_name is running normally." >> "$LOG_FILE"
    fi
}

# Fungsi memeriksa log systemd untuk pesan warning
check_journal_warnings() {
    local service_name="$1"
    local service_display_name="$2"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')

    # Cek log systemd untuk pesan warning
    local warning_message=$(journalctl -u "$service_name" -p warning --since "5 minutes ago" | grep "Journal was rotated")

    if [ -n "$warning_message" ]; then
        local warning_notification="━━━━━━━━━━━━━
*⚠️ Server Monitoring*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Warning Detected :* $service_display_name ⚠️
*⤿ Pesan Warning :* Journal was rotated
*⤿ Waktu :* $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$warning_notification"
        systemctl restart "$service_name"

        local restart_message="━━━━━━━━━━━━━
*✅ Server Monitoring*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Restart :* $service_display_name ✅
*⤿ Waktu Restart :* $current_time
━━━━━━━━━━━━━"

        send_telegram_notification "$restart_message"
        echo "[INFO] $current_time - $service_display_name restarted due to journal rotation warning." >> "$LOG_FILE"
    fi
}

# Fungsi memuat konfigurasi
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "Konfigurasi tidak ditemukan. Harap jalankan setup terlebih dahulu: sudo bash /usr/local/bin/service-fixing.sh setup"
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

    # Buat systemd service
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Service Fixing Script
After=network.target

[Service]
ExecStart=/usr/local/bin/service-fixing.sh run
Restart=always
User=root
EnvironmentFile=/etc/service-fixing.conf

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd dan aktifkan service
    systemctl daemon-reload
    systemctl enable service-fixing.service
    systemctl start service-fixing.service

    echo "Service berhasil dibuat dan dijalankan!"

    # Kirim notifikasi bahwa script selesai diinstall
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local install_message="━━━━━━━━━━━━━
*✅ Server Monitoring | @fernandairfan*
━━━━━━━━━━━━━
*⤿ Domain :* $DOMAIN
*⤿ Status :* Script started successfully!
*⤿ Waktu :* $current_time
━━━━━━━━━━━━━"

    send_telegram_notification "$install_message"
    exit 0
}

# Fungsi utama
main() {
    # Jika mode setup dipilih
    if [[ "$1" == "setup" ]]; then
        setup_config
        exit 0
    fi

    # Jika tidak dijalankan dengan `run`, maka jalankan setup dulu
    if [[ "$1" != "run" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo "🚀 Setup pertama kali..."
            setup_config
        else
            echo "✅ Konfigurasi sudah ada. Menjalankan sebagai service..."
            exec systemctl start service-fixing.service
        fi
    fi

    # Load konfigurasi dan jalankan service
    load_config
    echo "Service Fixing is running..."
    while true; do
        clean_log
        check_service "paradis" "vmess"
        check_service "sketsa" "vless"
        check_service "drawit" "trojan"

        # Cek log systemd untuk pesan warning
        check_journal_warnings "paradis" "vmess"
        check_journal_warnings "sketsa" "vless"
        check_journal_warnings "drawit" "trojan"

        sleep 120
    done
}

# Jalankan fungsi utama
main "$@"
