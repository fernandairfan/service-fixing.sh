Cara menjalankannya : 
- curl -s https://raw.githubusercontent.com/fernandairfan/service-fixing.sh/main/service-fixing.sh -o /usr/local/bin/service-fixing.sh && chmod +x /usr/local/bin/service-fixing.sh && bash /usr/local/bin/service-fixing.sh

Cara menghentikan Script : 
Step ~
- ps aux | grep service-fixing.sh
- kill <PID>

Atau langsung :
- pkill -f service-fixing.sh

Cek status service : 
- systemctl status service-fixing.service

Cara Remove :

- systemctl stop service-fixing.timer
- systemctl stop service-fixing.service
- systemctl disable service-fixing.timer
- systemctl disable service-fixing.service
- rm -f /etc/systemd/system/service-fixing.service
- rm -f /etc/systemd/system/service-fixing.timer
- systemctl daemon-reload
- rm -f /usr/local/bin/service-fixing.sh
-rm -f /etc/service-fixing.conf
- rm -f /var/log/service-fixing.log
