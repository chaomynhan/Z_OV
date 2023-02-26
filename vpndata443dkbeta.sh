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


    read -p "Nhập Node ID port 443 :" node_443
    echo -e "Node_80 là : ${node_443}"

    read -p "Nhập subdomain hoặc ip vps vpn cho port443:" CertDomain443
    echo -e "CertDomain port 443 là = ${CertDomain}"
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
  xrayr: 
    image: ghcr.io/xrayr-project/xrayr:latest
    volumes:
      - ./config.yml:/etc/XrayR/config.yml
      - ./dns.json:/etc/XrayR/dns.json
      - ./crt.crt:/etc/XrayR/crt.crt
      - ./key.key:/etc/XrayR/key.key
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
  cat >key.key <<EOF
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC/o2lC7vABk5CV
dgUtfAlpPrh7QdXOHO2fUq+L5YChPxJVNQFmN6XNmEDD5xKWsghTnC77u2DzPGTW
lBe/ou0xFX5+5SCqmRImqlWfF5XDIj6Pt5Z79WV3Ze/uzDolpdKZ9VVc3/5fbFeq
0Lzap24KanonMZfccssfcgqkLXsUt5xO5FJmhIaOa52UO0MjFJo1ioH3uRqnT/qp
jrkN8QYfCeCb7GyQfrh5WQ6Hk0fR5VvQTCc23+kogrNrwViRd0isYSxwsX6EYgCl
MTZcdmGUOjbuaFLmc6N1ONwH3DOnZiOD/ygihUUqk6LNRONZULAOPO1Caw34qDN7
aeQun9APAgMBAAECggEAEvthNEeNj2Jp+lv31FMKbZnQVSkmv+U+pj7e84j2jkI8
kyMOce0GJ9CybZUoUrPsvjdksfuT9VPgmx6NIabGPsvlvTT94NgLo7fQhlMkOvFb
6AljxwB+He8DbpBdHBiKPUS/QVVQkWweXOWTJ0dZT3/PfK1dYPEf7IvzwOJeZCVF
ySQB2WW3Ae99Oacn6OnmGdAzi1upfQyDrHz5IlnnzymKKcd95TlzZevDRDgjCxMs
SfheGeWDdVoxn9nYl+V4abDFE4fDMG3Uvj2QPTau74tab1gfsOSVtasrnLJNSZ7S
NXZQz12yzIpBcSne6q1OeTISsd5HfBG/LWYgmOJ+HQKBgQDrVgHTGE1QJlzl0fow
QQYBFnLyw23d0Mkl1JN7Rv7DUyyC5Pmh6OB2krUTy/hkm7Er1t9uw6FySmxUQT6m
yIY2/v4tyCl+/TyqmmXJ5oWKWMFHuT85Bl25N336/c3xfNNOWbXiDYRTn2rbaT6A
pxcKlKEP9y8HnwEvUQIMZD6mRQKBgQDQdyXazR5pMcEFrdnEqJsl64RtuHnRXba8
0LJgzasrvkPjJ3QntzOY8RCofUeqtgcY9SjO/0wOSb3/BNSV/hlhXxlCHy5uD1uN
12/GWDV+RmeQRueOhuPJng6/rnfytJiOwqqrn4DUHWLyrNTex7+f+T4CuJycHXay
fNC0MuvcQwKBgBK1YavAcNUAV75FdRhE8w8/E6BM/Pz3TiZdweO4/yPUBuPZBCdk
9gM3IoISYwrMfcc4a8bIcps9Y2NHVI25v0G7/8Tv9qyLwTjm0VS9qLwY1jS3e1kz
Mlw5FyDO8IJUJBBEfXsdC/oB4GLU+Q0NO32x1yQHyItYjqWOURVfGsPpAoGAAsbj
iTOcSRhxksrLENSSJIIrpG6FqOVPrto01hdHRXDmZJs8795/4HStnSD2GG8OTyXM
4l0CPVp8Hm6JCmp1GhfzNS9HJg4sUQpiocjBBaqYbJKVOQ/Q7vmdBq6jSGdhdN1g
+qJITAsMK2FkAIe2pMHkMpMU+vtlfmEtQok/HRMCgYEAlwGMbH+2i2IrerZV9kSe
Guj02k8rbi0rzH+YtSe0uka5JeIJtW7l8ecN0qLXI06R6uvRpylJwIIOK9OOHRbC
qVVOadqjDwx7tCD+CzVmyJvZCEsDdhG4aaALk+5Hh3/Xl9kR5uNG64UEY5R07U3b
LEtG0xKjXHvdRz5fozHJkvo=
-----END PRIVATE KEY-----

EOF
  cat >crt.crt <<EOF
-----BEGIN CERTIFICATE-----
MIIEojCCA4qgAwIBAgIUZxYtfhBTyrk10iPoV8yfWa/RB5EwDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTIzMDIyNjAyMjAwMFoXDTM4MDIyMjAyMjAwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv6NpQu7wAZOQlXYFLXwJaT64e0HVzhztn1Kv
i+WAoT8SVTUBZjelzZhAw+cSlrIIU5wu+7tg8zxk1pQXv6LtMRV+fuUgqpkSJqpV
nxeVwyI+j7eWe/Vld2Xv7sw6JaXSmfVVXN/+X2xXqtC82qduCmp6JzGX3HLLH3IK
pC17FLecTuRSZoSGjmudlDtDIxSaNYqB97kap0/6qY65DfEGHwngm+xskH64eVkO
h5NH0eVb0EwnNt/pKIKza8FYkXdIrGEscLF+hGIApTE2XHZhlDo27mhS5nOjdTjc
B9wzp2Yjg/8oIoVFKpOizUTjWVCwDjztQmsN+Kgze2nkLp/QDwIDAQABo4IBJDCC
ASAwDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBT0x2zmdBhFWBT6P/s2dh0MtSKSODAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTAlBgNVHREEHjAcgg0qLnZwbmRhdGEueHl6ggt2cG5kYXRhLnh5ejA4BgNVHR8E
MTAvMC2gK6AphidodHRwOi8vY3JsLmNsb3VkZmxhcmUuY29tL29yaWdpbl9jYS5j
cmwwDQYJKoZIhvcNAQELBQADggEBAFLtM3DodsGzVmKClNAM6jbFG4O2D3Lk19QW
X5jp/H7EorigU/r2ZE0jpZu/0X6YSb5rqldQqBotf05FLGCTxtXOMu1lgudFctZE
4bUqcOpi1JSDTcvHhtgt3Bnv9MANXLgziBSe9FRj5wH/4CjLTkCsyZI/AcbsHEzw
E08o8GNhCveHlcxRAJd/4GIQRI38MKLT4M2AlHTKIEP1V2zNBcGE3G5235W5nadJ
BDUGjEWauqkqdAR8kQ+6LLrtZp+F3XZMinPgnyg4U20jC4J1sm/pBV/+pdABzjyO
VtqwhxUMdMNqfNQlW3IovNiiZWLtXEaw4c2ycjE8YgQyxuuW1bU=
-----END CERTIFICATE-----
y
EOF
  cat >config.yml <<EOF
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # ./access.Log
  ErrorPath: # ./error.log
DnsConfigPath: # ./dns.json Path to dns config
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 10 # Connection idle time limit, Second
  UplinkOnly: 0 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 0 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel
    ApiConfig:
      ApiHost: "https://vpndata.xyz"
      ApiKey: "hoangskyht_hoangskyht"
      NodeID: $node_443
      NodeType: V2ray # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 10 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $DeviceLimit # Local settings will replace remote settings, 0 means disable
      RuleListPath: # ./rulelist Path to local arulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      DisableSniffing: true # Disable domain sniffing 
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI:  # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain443" # Domain to cert
        CertFile: ./crt.crt # Provided if the CertMode is file
        KeyFile: ./key.key
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
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
  echo -e "[${green}Info${plain}] Đặt múi giờ thành phố Hà Nội GTM+7"
  ln -sf /usr/share/zoneinfo/Asia/Hanoi  /etc/localtime
  date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}

#update_image
Update_xrayr() {
  cd ${cur_dir}
  echo "Tải Plugin DOCKER"
  docker-compose pull
  echo "Bắt đầu chạy dịch vụ DOCKER"
  docker-compose up -d
}

#show last 100 line log

logs_xrayr() {
  echo "nhật ký chạy sẽ được hiển thị"
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
  echo "đây là bản docker chạy 443"
  echo "hãy chú ý thêm ssl vào 2 file crt.crt và key.key"
  echo "nano crt.crt or nano key.key để sửa"
  echo "không hiểu hãy liên hệ zalo 0968343658"
  echo "tôi không thêm auto dán để mọi người đỡ lười khi chạy nếu bạn muốn auto có thể sửa theo cấu trúc"
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
