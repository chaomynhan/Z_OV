wget https://raw.githubusercontent.com/Swivro/ddos-protection-script/main/script-rhel.sh && chmod +x antiddos-rhel.sh && ./antiddos-rhel.sh
iptables-save  > /etc/iptables/rules.v4
systemctl start netfilter-persistent
systemctl restart netfilter-persistent
systemctl enable netfilter-persistent
systemctl status netfilter-persistent
echo "hoàn tất"
