clear
echo "   1. Install"
echo "   2. Config"
echo "   3. Get SSL"
echo "   4. Restart"
read -p "  Vui Lòng Nhập : " num

    case "${num}" in
        1) 
        yum -y install epel-release ; yum -y install wget zip unzip tar curl  && \
        yum -y install nano net-tools curl wget gc gcc gcc-c++ pcre-devel zlib-devel make wget openssl-devel libxml2-devel libxslt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel gperftools gperftools-devel perl-ExtUtils-Embed  && \
        yum -y install screen htop iotop iptraf nano net-tools gcc automake libffi-devel zlib zlib-devel gcc gcc-c++ autoconf apr-util-devel gc gcc gcc-c++ pcre-devel zlib-devel make wget openssl openssl-devel libxml2-devel libxslt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel gperftools gperftools-devel  perl-ExtUtils-Embed && \
        yum -y install gnutls-utils sshpass rsync && \
        yum -y install bind-utils sysstat bc tar curl wget gc gcc gcc-c++ pcre-devel zlib-devel make wget openssl-devel libxml2-devel libxslt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel gperftools gperftools-devel perl-ExtUtils-Embed gcc automake autoconf apr-util-devel gc gcc gcc-c++ pcre-devel zlib-devel make wget openssl openssl-devel libxml2-devel libxslt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel gperftools gperftools-devel perl-ExtUtils-Embed perl perl-devel perl-ExtUtils-Embed libxslt libxslt-devel libxml2 libxml2-devel gd gd-devel GeoIP GeoIP-devel gperftools-devel wget yum-utils make gcc openssl-devel bzip2-devel libffi-devel zlib-devel screen htop iotop iptraf nano net-tools gcc automake libffi-devel zlib zlib-devel gcc gcc-c++ autoconf apr-util-devel gc
        yum -y install libatomic_ops-devel
        ;;
        2) nano /vddos/conf.d/website.conf
        ;;
        3) openssl req -newkey rsa:2048 -x509 -sha256 -days 365 -nodes -out /root/azz.crt -keyout /root/azz.key -subj "/C=JP/ST=Tokyo/L=Chiyoda-ku/O=Google Trust Services LLC/CN=google.com"
        ;;
        4) vddos restart
        ;;
        *) exit
        ;;
    esac
