#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=$(pwd)
# Color
red='\033[0;31m'
green='\033[0;32m'
#yellow='\033[0;33m'
plain='\033[0m'
operation=(Install Update UpdateConfig logs restart delete)
# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] Chưa vào root kìa !, vui lòng xin phép ROOT trước!" && exit 1

#Check system
check_sys() {
  local checkType=$1
  local value=$2
  local release=''
  local systemPackage=''

  if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /etc/issue; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /proc/version; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
    systemPackage="yum"
  fi

  if [[ "${checkType}" == "sysRelease" ]]; then
    if [ "${value}" == "${release}" ]; then
      return 0
    else
      return 1
    fi
  elif [[ "${checkType}" == "packageManager" ]]; then
    if [ "${value}" == "${systemPackage}" ]; then
      return 0
    else
      return 1
    fi
  fi
}

# Get version
getversion() {
  if [[ -s /etc/redhat-release ]]; then
    grep -oE "[0-9.]+" /etc/redhat-release
  else
    grep -oE "[0-9.]+" /etc/issue
  fi
}

# CentOS version
centosversion() {
  if check_sys sysRelease centos; then
    local code=$1
    local version="$(getversion)"
    local main_ver=${version%%.*}
    if [ "$main_ver" == "$code" ]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

get_char() {
  SAVEDSTTY=$(stty -g)
  stty -echo
  stty cbreak
  dd if=/dev/tty bs=1 count=1 2>/dev/null
  stty -raw
  stty echo
  stty $SAVEDSTTY
}
error_detect_depends() {
  local command=$1
  local depend=$(echo "${command}" | awk '{print $4}')
  echo -e "[${green}Info${plain}] Bắt đầu cài đặt các gói ${depend}"
  ${command} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Cài đặt gói không thành công ${red}${depend}${plain}"
    exit 1
  fi
}

# Pre-installation settings
pre_install_docker_compose() {
#install key_path
    echo -e "[${Green}Nhận dạng web ${plain}] Link Web : https://vuthaiazz.xyz"
    read -p " ID nút (Node_ID_Vmess):" node_id_vmess_1
    [ -z "${node_id_vmess}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_vmess}"
    echo "-------------------------------"

    read -p " ID nút (Node_ID_Trojan):" node_id_trojan_1
    [ -z "${node_id_trojan}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_trojan}"
    echo "-------------------------------"

    read -p "Vui long nhập CertDomain :" CertDomain
    [ -z "${CertDomain}" ] && CertDomain=0
    echo "-------------------------------"
    echo -e "Domain: ${CertDomain}"
    echo "-------------------------------"

# giới hạn tốc độ
    read -p " Giới hạn tốc độ (Mbps):" limit_speed
    [ -z "${limit_speed}" ] && limit_speed=0
    echo "-------------------------------"
    echo -e "Giới hạn tốc độ: ${limit_speed}"
    echo "-------------------------------"

# giới hạn thiết bị
    read -p " Giới hạn thiết bị (Limit):" limit
    [ -z "${limit}" ] && limit=0
    echo "-------------------------------"
    echo -e "Limit: ${limit}"
    echo "-------------------------------"
}

# Config docker
config_docker() {
  cd ${cur_dir} || exit
  echo "Bắt đầu cài đặt các gói"
  install_dependencies
  echo "Tải tệp cấu hình DOCKER"
  cat >docker-compose.yml <<EOF
version: '3'
services:
  aikor:
    image: aikocute/aikor:latest
    volumes:
      - ./aiko.yml:/etc/AikoR/aiko.yml # thư mục cấu hình bản đồ
      - ./dns.json:/etc/AikoR/dns.json
      - ./server.pem:/etc/AikoR/server.pem
      - ./privkey.pem:/etc/AikoR/privkey.pem
    restart: always
    network_mode: host
EOF
  cat >dns.json <<EOF
{
    "servers": [
        "1.1.1.1",
        "8.8.8.8",
        "localhost"
    ],
    "tag": "dns_inbound"
}
EOF

  cat >aiko.yml <<EOF
Log:
  Level: none # Log level: none, error, warning, info, debug
  AccessPath: # /etc/AikoR/access.Log
  ErrorPath: # /etc/AikoR/error.log
DnsConfigPath: # /etc/AikoR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/AikoR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/AikoR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/AikoR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 86400 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://vuthaiazz.xyz"
      ApiKey: "1122334455667788"
      NodeID: $node_id_trojan_1
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath:  # ./rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/AikoR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/AikoR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://vuthaiazz.xyz"
      ApiKey: "1122334455667788"
      NodeID: $node_id_vmess_1
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed  # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath:  # ./rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
EOF
    cat >server.pem <<EOF
-----BEGIN CERTIFICATE-----
MIIEpjCCA46gAwIBAgIUWhjg5WkuAGieP1GBFZoN25NkWHswDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTIyMDgyNDE2MDcwMFoXDTI1MDgyMzE2MDcwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyL2dwZgsyFlU2q7ojpSowH3QCjLUYkrg38hR
Kp/UY8akCKbuPP+dSiuLN8acWiMW71uQ+PNxdd2avUx5/cMAv69OXyKDEb6My6HJ
lmbftUNBUhU1xPpKpYHCt7d91AOeBwOJv+YFxDejY6zkmmRxaf5HFI7p3do6uqWq
4voKe8ZyWODzSvqpBYl1YH1bn6lsDDCAlRHVwrM2k8X3xXk0Du9BKXYFXABEf1bb
3KoyT7m7aKhUzmOZvicoKAq7b8501zMxW3qY9juKC4YIoX1G76mynrL5W4THyp8P
XgRpln2NLI/vpLHedJcIaoxHR/6uKYapHBEJWtrPl646TXhOYQIDAQABo4IBKDCC
ASQwDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBS4Anogd7uMisx9CGTefV209OFW/zAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTApBgNVHREEIjAggg8qLnZ1dGhhaWF6ei54eXqCDXZ1dGhhaWF6ei54eXowOAYD
VR0fBDEwLzAtoCugKYYnaHR0cDovL2NybC5jbG91ZGZsYXJlLmNvbS9vcmlnaW5f
Y2EuY3JsMA0GCSqGSIb3DQEBCwUAA4IBAQCcYkJA1kztWtV3eOlx5NntB3nNnVJR
rvdMPBJ3zdh7dv9SxFIiac1pq2w+mVhSn1SraP82F62yH/NMoaDSXQ+A/JZHaYuM
TeTYQQ3zTbTLvfhrSCJAX3AvH2n23ajgQcLPyNVWLz3WofS13+jOJaENUR+On3iu
ZmW/ykgLLOYi3mZ1B1X2Sf181yrYwv7kh80DXcTFAqTiioUMr3b98Q7zZnXd36Y9
ilfQaJjmYlpbxdz06npBk+2S9idvr0q3nuUYJsmAITqwkT7RFvAwU14QtnqKcZbu
839SCd4RvlaGFGvSM443IeeSCJTxTYcpYHSiUyr9b/Y6xhPMQR0wjYUX
-----END CERTIFICATE-----
EOF
    cat >privkey.pem <<EOF
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDIvZ3BmCzIWVTa
ruiOlKjAfdAKMtRiSuDfyFEqn9RjxqQIpu48/51KK4s3xpxaIxbvW5D483F13Zq9
THn9wwC/r05fIoMRvozLocmWZt+1Q0FSFTXE+kqlgcK3t33UA54HA4m/5gXEN6Nj
rOSaZHFp/kcUjund2jq6pari+gp7xnJY4PNK+qkFiXVgfVufqWwMMICVEdXCszaT
xffFeTQO70EpdgVcAER/VtvcqjJPubtoqFTOY5m+JygoCrtvznTXMzFbepj2O4oL
hgihfUbvqbKesvlbhMfKnw9eBGmWfY0sj++ksd50lwhqjEdH/q4phqkcEQla2s+X
rjpNeE5hAgMBAAECggEAApbJelX5W+MlEEX5u18I9ySYQo1pxlPDZzd47oUNsvS8
qFzozTIZx/tcSg2edh4mPVOPwNo48CV5ya+7Eg4KDC7ZYqo6CQhNXhH53N36TCbw
KHwcC6yTumM8TOzJq2qZhushg29WyzNRgOdZsnERsmWEaqw2MXWPVNlupQtHB9Yf
RBNyJk7FG9lFWD8tIpxM3gJ3gEy0Rz6p3dJ2IaZeAxad5zD7RZ7vtkqGryhmB+WT
QnGfgHwiKv0sCjnecQg75AHrdF/NLO3bfixBYI3YaedU4Iozwxt6T8VsbAJSkAMz
8O+SddK4bThau0WkAZdYq1ZnuOuEFNdDixW3nKNjQQKBgQD3sbUpwcc+RysP7SQl
a/gsW/BH/N2UG0Pt3sO6h7Tn45LwbshYwZckl7Zc8t/7hOAwymZYRNIrTDfKhhGf
wU2dLVmUVmGHp7so7yqgJ5+d5fqK0ucAo/g47DVJpaXAt5dnuKpGsmLZ+Zuuekg+
2EUrsvn7zcohIrase2DSfaTiMQKBgQDPeNf5xEjeyD+YtK+kDnWDvXnWr+rJgZf8
dtI/oWk8gmV6z3W69VwTfnWSUR5uIMG4CvKTVVugOtyA30GEzqFF1awLBhSV0VS2
0EMDEpiKTAOSJFymxdzXyOn6l1vWH7VSnSizgMD41oO7k1Ldbz1BI53YvqUZU9Mn
n6so291zMQKBgQCjbWwz3fhBPiHKg1QLIN8BHbQ/OzdTpl2+j/GinDGfosbrvpyP
+0NnUHZxg4qHYJeveYvnh5kIGmThSm5McvVr1GU7e3ckU2YozwzX2Oz2+KvDdv4V
rRp1LFzId/QSYNAUDoLC3KZeXdP7XhFW7clN2OwZ2SEZldbjnRA4MdBdsQKBgFwv
lcelL7vNvnRb1K9QvWaMClcaU3i13JKROVqMnfYE+pJXHDi2TPNcfWFGKf9FDs54
DtDoXI4VmWSpzrL0HTSqfIdpbDwlhz6zyxLScHUC0ZNeFM0FndtDqrNuDaBW9np+
2lboHtZyepYeH/PEObN33+suyq02UdyJVcQR7ZQBAoGBAMJXGzqREPB0UZRQMBXO
89MF1V1ucf3rMe//ovM3Ux4H4CGLOheTSOfxjF9OB/sd5xmk3F7id5Lrba8NoXCE
JndEbDDmr7oc8mJshjDNIe9O3dpJyV/dTwHHrvRJnzE2AsigtYbeq44EIVXAIMMJ
qJ/4xo/oVDaP6oe4RZSifqu2
-----END PRIVATE KEY-----
EOF
}

# Install docker and docker compose
install_docker() {
  echo -e "bắt đầu cài đặt DOCKER "
 sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
systemctl start docker
systemctl enable docker
  echo -e "bắt đầu cài đặt Docker Compose "
curl -fsSL https://get.docker.com | bash -s docker
curl -L "https://github.com/docker/compose/releases/download/1.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
  echo "khởi động Docker "
  service docker start
  echo "khởi động Docker-Compose "
  docker-compose up -d
  echo
  echo -e "Đã hoàn tất cài đặt phụ trợ ！"
  echo -e "0 0 */3 * *  cd /root/${cur_dir} && /usr/local/bin/docker-compose pull && /usr/local/bin/docker-compose up -d" >>/etc/crontab
  echo -e "Cài đặt cập nhật thời gian kết thúc đã hoàn tất! hệ thống sẽ update sau [${green}24H${plain}] Từ lúc bạn cài đặt"
}

install_check() {
  if check_sys packageManager yum || check_sys packageManager apt; then
    if centosversion 5; then
      return 1
    fi
    return 0
  else
    return 1
  fi
}

install_dependencies() {
  if check_sys packageManager yum; then
    echo -e "[${green}Info${plain}] Kiểm tra kho EPEL ..."
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
      yum install -y epel-release >/dev/null 2>&1
    fi
    [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Không cài đặt được kho EPEL, vui lòng kiểm tra." && exit 1
    [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils >/dev/null 2>&1
    [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel >/dev/null 2>&1
    echo -e "[${green}Info${plain}] Kiểm tra xem kho lưu trữ EPEL đã hoàn tất chưa ..."

    yum_depends=(
      curl
    )
    for depend in ${yum_depends[@]}; do
      error_detect_depends "yum -y install ${depend}"
    done
  elif check_sys packageManager apt; then
    apt_depends=(
      curl
    )
    apt-get -y update
    for depend in ${apt_depends[@]}; do
      error_detect_depends "apt-get -y install ${depend}"
    done
  fi
  echo -e "[${green}Info${plain}] Đặt múi giờ thành Hồ Chí Minh GTM+7"
  ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh  /etc/localtime
  date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}

#update_image
Update_xrayr() {
  cd ${cur_dir}
  echo "Tải hình ảnh DOCKER"
  docker-compose pull
  echo "Bắt đầu chạy dịch vụ DOCKER"
  docker-compose up -d
}

#show last 100 line log

logs_xrayr() {
  echo "100 dòng nhật ký chạy sẽ được hiển thị"
  docker-compose logs --tail 100
}

# Update config
UpdateConfig_xrayr() {
  cd ${cur_dir}
  echo "đóng dịch vụ hiện tại"
  docker-compose down
  pre_install_docker_compose
  config_docker
  echo "Bắt đầu chạy dịch vụ DOKCER"
  docker-compose up -d
}

restart_xrayr() {
  cd ${cur_dir}
  docker-compose down
  docker-compose up -d
  echo "Khởi động lại thành công!"
}
delete_xrayr() {
  cd ${cur_dir}
  docker-compose down
  cd ~
  rm -Rf ${cur_dir}
  echo "đã xóa thành công!"
}
# Install xrayr
Install_xrayr() {
  pre_install_docker_compose
  config_docker
  install_docker
}

# Initialization step
clear
while true; do
  echo "-----XrayR Aiko-----"
  echo "Địa chỉ dự án và tài liệu trợ giúp:  https://github.com/AikoCute/XrayR"
  echo "AikoCute Hột Me"
  echo "Vui lòng nhập một số để Thực Hiện Câu Lệnh:"
  for ((i = 1; i <= ${#operation[@]}; i++)); do
    hint="${operation[$i - 1]}"
    echo -e "${green}${i}${plain}) ${hint}"
  done
  read -p "Vui lòng chọn một số và nhấn Enter (Enter theo mặc định ${operation[0]}):" selected
  [ -z "${selected}" ] && selected="1"
  case "${selected}" in
  1 | 2 | 3 | 4 | 5 | 6 | 7)
    echo
    echo "Bắt Đầu : ${operation[${selected} - 1]}"
    echo
    ${operation[${selected} - 1]}_xrayr
    break
    ;;
  *)
    echo -e "[${red}Error${plain}] Vui lòng nhập số chính xác [1-6]"
    ;;
  esac
done
history -c
0