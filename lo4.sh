
# iptables (nftables), iptables, ip6tables (nftables), ipset
IP="/sbin/iptables-nft"
IPT="/sbin/iptables"
IP6="/sbin/ip6tables-nft"
IPS="/sbin/ipset"

# SSH Port
# For example: 2222
# You dont have SSH?
# Then dont touch this
# Default: 22 (ssh)
SSH="ssh"

# Connection limit (per one IP)
# Recommended: 100
# If you server has only SSH,
# And you are under TCP DDoS,
# You can set here value ~50
CL="100"

# Enable SYN Proxy for some ports
# To mitigate powerful SYN Floods
SYNPROXY="22,80,443"

# Port of your webserver
# For example: 8080
# You dont have webserver?
# Then dont touch this
# Default: 80 (http)
HTTP="http"
HTTP="https"
# Connection limit action
# Recommended: REJECT
# Under DDoS you can set DROP here
# To reduce the load on the CPU
CLA="REJECT --reject-with tcp-reset"

# Useragent block action
# Recommended: REJECT
# You should use WAF if you under attack
# Or if u are use HTTPS+HSTS
UBA="REJECT --reject-with tcp-reset"

# Proto block action
# Recommended: ICMP proto unreach message
# Under DDoS (Layer3) you can try to change it
# To DROP, it will reduce CPU Load
PBA="REJECT --reject-with icmp-proto-unreachable"

# IP Block action
# Recommended: DROP
# No need to change it without reason.
# DROP action for IP that scanning your server
# Better than REJECT or something like it
IBA="DROP"

# TCP Port Block action
# Recommended: DROP
TPBA="DROP"

# UDP Port Block action
# Recommended: DROP
UPBA="DROP"

# Color
LightBlue='\033[1;36m'

# --------------------------------

# Show warning if the script is not started as root

if [ "$(whoami)" != "root" ]; then
         echo -e "${LightBlue}[!] Run this script as root"
        exit 255
fi

# --------------------------------

# Backup sysctl file, if it exists it will be overwritten
cp /etc/sysctl.conf{,.backup}

# --------------------------------

# Delete previous netfilter rules
nft flush chain inet filter input

# Reset iptables counters
"$IP" -Z
"$IPT" -Z

# Remove user chains in iptables
"$IP" -X
"$IPT" -X

clear;

# --------------------------------

# Allow lo without any limits
# To fix problems with reverse-proxy (like nginx)
# While used on same machine
# --------------------------------
 "$IP" -I INPUT -i lo -j ACCEPT
 "$IP" -I OUTPUT -o lo -j ACCEPT

# Protection against SYN-DoS
# --------------------------------
 "$IP" -t raw -I PREROUTING -p tcp --syn --match hashlimit --hashlimit-above 4/second --hashlimit-mode srcip --hashlimit-name synflood -j DROP

# Main ICMP Protection (Block ICMP Floods, ICMP Timestamping, etc)
# ----------------------------------------------------------------
 "$IP" -t raw -I PREROUTING -p icmp --icmp-type address-mask-request -j DROP
 "$IP" -t raw -I PREROUTING -p icmp --icmp-type router-solicitation -j DROP
 "$IP" -t raw -I PREROUTING -p icmp --icmp-type timestamp-request -j DROP
 "$IP" -t raw -A PREROUTING -p icmp --icmp-type echo-request -m limit --limit 2/s -j ACCEPT
 "$IP" -t raw -A PREROUTING -p icmp --icmp-type echo-request -j DROP
 "$IP" -t raw -A PREROUTING -p icmp -m limit --limit 2/s -j ACCEPT
 "$IP" -t raw -A PREROUTING -p icmp -j DROP

# Limit outgoing ICMP Port-unreachable messages
# Helps fight off UDP DDoS on random destination ports
# --------------------------------
 "$IP" -t raw -A OUTPUT -p icmp --icmp-type port-unreach -m limit --limit 11/m -j ACCEPT
 "$IP" -t raw -A OUTPUT -p icmp --icmp-type port-unreach -j DROP

# Block bogus TCP flags
# Helps fight off TCP Null Attack, TCP XMAS Attack,
# And other attack types with invalid TCP Flags.
# ----------------------------------------------------------------
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ALL NONE -j DROP
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ALL ALL -j DROP

# Block some unsecure/useless ports to increase security
# ----------------------------------------------------------------
 "$IP" -t raw -I PREROUTING -p UDP -m multiport --dports 7,19,25,135,136,137,138,139,445,1900,3389,5060 -j "$TPBA"
 "$IP" -t raw -I PREROUTING -p TCP -m multiport --dports 7,19,25,135,136,137,138,139,445,1900,3389,5060 -j "$UPBA"

# Block LAND and BLAT Attack
# --------------------------------
 "$IP" -t raw -I PREROUTING -s 127.0.0.0/8 ! -i lo -j DROP

# Limit incoming DNS and NTP packets
# --------------------------------
 "$IP" -t raw -A PREROUTING -p udp --sport 123 -m limit --limit 2/s --limit-burst 1 -j ACCEPT
 "$IP" -t raw -A PREROUTING -p udp --sport 53 -m limit --limit 4/s --limit-burst 10 -j ACCEPT
 "$IP" -t raw -A PREROUTING -p udp -m multiport --sports 53,123,17185,7001,1900,9000 -j DROP

# Block zero-length TCP and UDP
# Helps fight off UDP-NULL, TCP-NULL attacks
# --------------------------------
 "$IP" -t raw -I PREROUTING -p tcp -m length --length 0 -j DROP
 "$IP" -t raw -I PREROUTING -p udp -m length --length 0 -j DROP

# Limit connections per one IP
# --------------------------------
 "$IP" -t mangle -I PREROUTING -p tcp -m connlimit --connlimit-above "$CL" -j "$CLA"

# Limit incoming TCP RST and TCP FIN packets
# --------------------------------
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 3 -j ACCEPT
 "$IP" -t raw -A PREROUTING -p tcp --tcp-flags RST RST -j DROP

# Protect SSH against many conn attemps per minute from one IP
# --------------------------------
 "$IP" -t mangle -I PREROUTING -p tcp --dport "$SSH" -m state --state NEW -m recent --set
 "$IP" -t mangle -I PREROUTING -p tcp --dport "$SSH" -m state --state NEW -m recent --update --seconds 60 --hitcount 20 -j DROP

# Block SYNOPT-ACK Method
# --------------------------------
 "$IP" -t raw -A PREROUTING -p tcp --sport 21 --dport 21 --tcp-flags SYN,ACK SYN,ACK -j DROP

# Block UDP to SSH
# --------------------------------
 "$IP" -t raw -A PREROUTING -p udp --dport $SSH -j REJECT --reject-with icmp-port-unreach

# Redirect packets with INVALID or UNTRACKED state to SYNPROXY
# --------------------------------
 "$IP" -I INPUT -p tcp -m multiport --dports $SYNPROXY -m conntrack --ctstate INVALID,UNTRACKED -j SYNPROXY --timestamp --sack-perm

# Drop UDP and TCP packets with incorrect source port
# --------------------------------
 "$IP" -t raw -A PREROUTING -p udp ! --sport 0:65535 -j DROP
 "$IP" -t raw -A PREROUTING -p tcp ! --sport 0:65535 -j DROP

# Drop all fragmented packets
# Helps fight off fragmented floods
# --------------------------------
 "$IP" -t raw -A PREROUTING -f -j DROP

# Block new packets that not SYN
# Helps fight off TCP ACK/FIN/RST floods
# --------------------------------
 "$IP" -t mangle -I PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

# Block unusual TCP MSS Value
# --------------------------------
 "$IP" -t mangle -I PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP

# Block SYN sPort less than 1024
# --------------------------------
 "$IP" -t raw -I PREROUTING -p tcp --syn ! --sport 1024:65535 -j DROP

# Block suspicious useragents
# --------------------------------
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'WordPress' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'stresser' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'benchmark' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'MD5(' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'censys' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'inspect' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'scaner' --algo kmp -j "$UBA"
 "$IP" -A INPUT -p tcp --dport "$HTTP" -m string --string 'shodan' --algo kmp -j "$UBA"

# Block invalid SNMP Length
# --------------------------------
 "$IP" -t raw -A PREROUTING -p udp --sport 161 -m length --length 2536 -j DROP
 "$IP" -t raw -A PREROUTING -p udp --sport 161 -m length --length 1244 -j DROP

# Block some Layer3 Protocols
# Helps fight off ESP/GRE/AH floods
# If you need these protocols - uncomment these rules,
# or replace PBA variable to ACCEPT
# --------------------------------
 "$IP" -t raw -A PREROUTING -p esp -j "$PBA"
 "$IP" -t raw -A PREROUTING -p gre -j "$PBA"
 "$IP" -t raw -A PREROUTING -p ah -j "$PBA"

# Block all packets from broadcast
# Helps fight off Fraggle attacks & Smurf attacks
# --------------------------------
 "$IP" -t raw -I PREROUTING -m pkttype --pkt-type broadcast -j DROP

# Block IPv4 Packets with SSR
 "$IP" -t raw -A PREROUTING -m ipv4options --ssrr -j DROP

# IPv6 Protection
# Helps fight off: Simple ICMPv6 Attacks, Simple SYN Floods
# ----------------------------------------------------------------
 "$IP6" -t raw -A PREROUTING -p icmpv6 -m limit --limit 4/s -j ACCEPT
 "$IP6" -t raw -A PREROUTING -p icmpv6 -j DROP
 "$IP6" -t raw -A PREROUTING -p tcp --syn -m limit --limit 3/s --limit-burst 10 -j ACCEPT
 "$IP6" -t raw -A PREROUTING -p tcp --syn -j DROP

# Block some multicast IPs, censys IPs, shodan IPs
# Here we use ipset with big hashsize, so it doesnt affect performance
# --------------------------------
 "$IPS" create blacklist nethash hashsize 260000
 "$IPS" add blacklist 240.0.0.0/5
 "$IPS" add blacklist 172.16.0.0/12
 "$IPS" add blacklist 169.254.0.0/16
 "$IPS" add blacklist 224.0.0.0/3
 "$IPS" add blacklist 162.142.125.0/24
 "$IPS" add blacklist 167.94.138.0/24
 "$IPS" add blacklist 198.20.69.0/24
 "$IPS" add blacklist 198.20.70.114
 "$IPS" add blacklist 93.120.27.62
 "$IPS" add blacklist 66.240.236.119
 "$IPS" add blacklist 66.240.205.34
 "$IPS" add blacklist 198.20.99.130
 "$IPS" add blacklist 71.6.135.131
 "$IPS" add blacklist 66.240.192.138
 "$IPS" add blacklist 71.6.167.142
 "$IPS" add blacklist 82.221.105.0/24
 "$IPS" add blacklist 71.6.165.200
 "$IPS" add blacklist 188.138.9.50
 "$IPS" add blacklist 85.25.103.50
 "$IPS" add blacklist 85.25.43.94
 "$IPS" add blacklist 71.6.146.185
 "$IPS" add blacklist 71.6.158.166
 "$IPS" add blacklist 198.20.87.98
 "$IPS" add blacklist 185.163.109.66
 "$IPS" add blacklist 94.102.49.0/24
 "$IPS" add blacklist 104.131.0.69
 "$IPS" add blacklist 104.236.198.48
 "$IPS" add blacklist 155.94.222.0/24
 "$IPS" add blacklist 155.94.254.0/24
 "$IPS" add blacklist 162.142.125.0/24
 "$IPS" add blacklist 167.94.138.0/24
 "$IPS" add blacklist 167.94.145.0/24
 "$IPS" add blacklist 167.94.146.0/24
 "$IPS" add blacklist 167.248.133.0/24
 "$IPS" add blacklist 2602:80d:1000:b0cc:e::/80
 "$IPS" add blacklist 2620:96:e000:b0cc:e::/80
 "$IP" -t raw -A PREROUTING -m set --match-set blacklist src -j "$IBA"

# Advanced rules
 # OVH Bypass payload
 # --------------------------------
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "\x77\x47\x5E\x27\x7A\x4E\x09\xF7\xC7\xC0\xE6" -j DROP

 # SAO-UDP Bypass payload
 # --------------------------------
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU" -j DROP

 # TCP Patches
 # --------------------------------
  "$IP" -t raw -I PREROUTING -p tcp -m length --length 40 -m string --algo bm --string "0xd3da" -m state --state ESTABLISHED -j DROP
  "$IP" -t raw -I PREROUTING -p tcp -m length --length 40 -m string --algo bm --string "0x912e" -m state --state ESTABLISHED -j DROP
  "$IP" -t raw -I PREROUTING -p tcp -m length --length 40 -m string --algo bm --string "0x0c54" -m state --state ESTABLISHED -j DROP
  "$IP" -t raw -I PREROUTING -p tcp -m length --length 40 -m string --algo bm --string "0x38d3" -m state --state ESTABLISHED -j DROP

 # Botnet Attack filters
 # --------------------------------
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "2&0xFFFF=0x2:0x0100" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "12&0xFFFFFF00=0xC0A80F00" -j DROP
  "$IP" -t raw -A PREROUTING -p tcp -syn -m length --length 52 u32 --u32 "12&0xFFFFFF00=0xc838" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m length --length 28 -m string --algo bm --string "0x0010" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m length --length 28 -m string --algo bm --string "0x0000" -j DROP
  "$IP" -t raw -A PREROUTING -p tcp -m length --length 40 -m string --algo bm --string "0x0020" -j DROP
  "$IP" -t raw -A PREROUTING -p tcp -m length --length 40 -m string --algo bm --string "0x0c54" -j DROP
  "$IP" -t raw -A PREROUTING -p tcp --tcp-flags ACK ACK -m length --length 52 -m string --algo bm --string "0x912e" -m state --state ESTABLISHED -j DROP
  "$IP" -t mangle -A PREROUTING -p tcp -syn -m length --length 52 -m string --algo bm --string "0xc838" -m state --state ESTABLISHED -j DROP

 # Suspicious string filters
 # --------------------------------
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "CRI" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "STD" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "std" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "SAAM" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "ddos" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "flood" -j DROP

 # Sophiscated NULL method patches
 # --------------------------------
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "0x00000" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --string "0x000000000001" -j DROP

 # NTP Reflection block
 # --------------------------------
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "0>>22&0x3C@8" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "0>>22&0x3C@8&0xFF=42" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "0>>22&0x3C@8&0xFF" -j DROP

 # Block private bypasses
 # --------------------------------
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|424f4f5445524e4554|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|41545441434b|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|504r574552|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|736b6964|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|6c6e6f6172656162756e6386f6673b694464696573|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|736b6954|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|736b69646e6574|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m string --algo bm --hex-string "|4a554e4b2041545441434b|" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m multiport --dports 16000:29000,"$SSH" -m string --to 75 --algo bm --string 'HTTP/1.1 200 OK' -j DROP
  "$IP" -t raw -A PREROUTING -p udp --dport 16000:29000 -m string --to 75 --algo bm --string 'HTTP/1.1 200 OK' -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m udp -m string --hex-string "|7374640000000000|" --algo kmp --from 28 --to 29 -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "6&0xFF=0,2:5,7:16,18:255" -j DROP
  "$IP" -t raw -A PREROUTING -m u32 --u32 "12&0xFFFF=0xFFFF" -j DROP
  "$IP" -t raw -A PREROUTING -m u32 --u32 "28&0x00000FF0=0xFEDFFFFF" -j DROP
  "$IP" -t raw -A PREROUTING -m string --algo bm --from 28 --to 29 --string "farewell" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m u32 --u32 "28 & 0x00FF00FF = 0x00200020 && 32 & 0x00FF00FF = 0x00200020 && 36 & 0x00FF00FF = 0x00200020 && 40 & 0x00FF00FF = 0x00200020" -j DROP
  "$IP" -t raw -A PREROUTING -p udp -m udp -m string --hex-string "|53414d50|" --algo kmp --from 28 --to 29 -j DROP 




 echo -e "
#
# /etc/sysctl.conf - Configuration file for setting system variables
# See /etc/sysctl.d/ for additional system variables.
# See sysctl.conf (5) for information.
# Custom netfilter timeouts.
# --------------------------------
 net.netfilter.nf_conntrack_tcp_timeout_last_ack = 10
 net.netfilter.nf_conntrack_tcp_timeout_close = 5
 net.netfilter.nf_conntrack_tcp_timeout_close_wait = 3
 net.netfilter.nf_conntrack_tcp_timeout_time_wait = 1
 net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 15
 net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 15
 net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 15
 net.netfilter.nf_conntrack_tcp_timeout_unacknowledged = 30
 net.netfilter.nf_conntrack_generic_timeout = 120
 net.netfilter.nf_conntrack_udp_timeout_stream = 30
 net.netfilter.nf_conntrack_udp_timeout = 10
 net.netfilter.nf_conntrack_icmp_timeout = 1
 net.netfilter.nf_conntrack_icmpv6_timeout = 1
# SYN Cookies and custom SYN Backlog.
# --------------------------------
 net.ipv4.tcp_syncookies = 1
 # Change value above to 2,
 # If you are under SYN DoS,
 # And if your server is slow.
 # Value '2' means that SYN-Cookies are always enabled.
# Custom limit for max opened files.
# --------------------------------
 fs.file-max = 800000
# Custom limit for max opened connections.
# --------------------------------
 net.core.somaxconn = 20000
# TCP TimeWait Reuse.
# --------------------------------
 net.ipv4.tcp_tw_reuse = 1
# Custom SYN and SYN-ACK Retries.
# --------------------------------
 net.ipv4.tcp_synack_retries = 1
 net.ipv4.tcp_syn_retries = 2
# RFC 1337.
# --------------------------------
 net.ipv4.tcp_rfc1337 = 1
# Custom big network buffers.
# --------------------------------
 net.core.rmem_max = 33554432
 net.core.wmem_max = 33554432
# Use TCP MTU Probing when ICMP Blackhole detected.
# --------------------------------
 net.ipv4.tcp_mtu_probing = 1
# Custom insane route table size.
# --------------------------------
 net.ipv6.route.max_size = 2147483647
 net.ipv4.route.max_size = 2147483647
# Network hardening.
# --------------------------------
 net.ipv4.conf.all.accept_redirects = 0
 net.ipv4.conf.all.secure_redirects = 0
 net.ipv6.conf.all.accept_redirects = 0
 net.ipv4.conf.all.send_redirects = 0
 net.ipv4.conf.all.accept_source_route = 0
 net.ipv6.conf.all.accept_source_route = 0
 net.ipv6.conf.all.accept_ra = 0
 net.ipv6.conf.all.ignore_multicast = 1
 net.ipv6.conf.all.ignore_anycast = 1
 net.ipv4.icmp.all.ignore_broadcasts = 1
 net.ipv6.conf.all.accept_redirect = 0
 net.ipv4.conf.all.secure_redirects = 1
 net.ipv6.icmp.all.ignore_anycast = 1
 net.ipv6.icmp.all.ignore_multicast = 1
 net.ipv6.conf.all.drop_unsolicited_na = 1
 net.ipv6.conf.all.use_tempaddr = 2
 net.ipv4.conf.all.drop_unicast_in_l2_multicast = 1
 net.ipv6.conf.all.drop_unicast_in_l2_multicast = 1
 net.ipv6.conf.default.dad_transmits = 0
 net.ipv6.conf.default.autoconf = 0
# Prevent ARP Spoofing.
# --------------------------------
 net.ipv4.conf.all.drop_gratuitous_arp = 1
 net.ipv4.conf.all.arp_ignore = 1
# Disable IGMP Multicast reports.
# --------------------------------
 net.ipv4.igmp_link_local_mcast_reports = 0
# Overall kernel hardening.
# --------------------------------
 kernel.dmesg_restrict = 1
 kernel.kptr_restrict = 1
 kernel.nmi_watchdog = 0
 fs.protected_symlinks = 1
 fs.protected_hardlinks = 1
 fs.protected_fifos = 2
 fs.protected_regular = 2
 kernel.unprivileged_bpf_disabled = 1
 kernel.unprivileged_userns_clone = 0
 kernel.printk = 3 3 3 3
 net.core.bpf_jit_harden = 2
 vm.unprivileged_userfaultfd = 0
 kernel.kexec_load_disabled = 1
 #kernel.sysrq = 0 # Disables sysrq (may cause problems)
 #net.ipv4.ip_forward = 0 # Disables ip_forward (may block VPN)
# Performance tuning.
# --------------------------------
 kernel.sched_tunable_scaling = 1
 net.ipv4.tcp_moderate_rcvbuf = 1
 net.ipv4.tcp_slow_start_after_idle = 0
 net.ipv4.tcp_sack = 1
 net.ipv4.tcp_fack = 1
 net.ipv4.tcp_ecn = 2
# Block exploits.
# --------------------------------
 kernel.randomize_va_space = 2
 kernel.exec-shield = 2
# Enable kernel panic autoreboot.
# --------------------------------
 kernel.panic = 10
# Ignore ICMP Bogus responses.
# --------------------------------
 net.ipv4.icmp_ignore_bogus_error_responses = 1
# Disable conntrack helper.
# --------------------------------
 net.netfilter.nf_conntrack_helper = 0
# Increase max available source ports.
# --------------------------------
 net.ipv4.ip_local_port_range=1024 65535
# Disable conntrack TCP Loose (we need this to enable SYN Proxy).
# --------------------------------
 net.netfilter.nf_conntrack_tcp_loose = 0
# Reverse-path filter.
# You should set '1' to '2' if you are use assymetric routing.
# --------------------------------
 net.ipv4.conf.all.rp_filter = 1
# Increase max conntrack table size.
# --------------------------------
 net.netfilter.nf_conntrack_max = 10000000
# Power optimization.
# --------------------------------
 kernel.sched_energy_aware = 1" > /etc/sysctl.conf

sysctl -p;
systemctl enable --now netfilter-persistent
clear;
# Remove 'clear' if you wanna to see stdout

echo -e "${LightBlue}"
echo -e "[✓] Script changes applied, but iptables rules are not saved.
Check the network now, and if it works, save the rules manually with sudo 'netfilter-persistent save'\n"
echo -e "Also, you can check some info about rules (example: dropped packets),
With 'nft list ruleset'"
exit 0;
