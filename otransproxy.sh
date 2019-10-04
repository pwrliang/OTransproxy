#!/usr/bin/env sh
WORKPLACE=$(dirname "$0")
TMP=$WORKPLACE/tmp
ACCELERATED_DOMAINS_CONF=$TMP/transproxy_accelerated_domains.conf
ALLOW_LIST_CONF=$TMP/transproxy_allowlist.conf
BLOCK_LIST_CONF=$TMP/transproxy_blocklist.conf
DNS_SERVER_CONF=$TMP/transproxy_server.conf
DNSMASQ_CONF=/tmp/dnsmasq.d
UPSTREAM_DNS="192.168.1.1"
if [ -f "/tmp/resolv.conf.auto" ]; then
  UPSTREAM_DNS=$(cut -d " " -f 2 </tmp/resolv.conf.auto|grep -v 0.0.0.0|grep -v 127.0.0.1|sed -n 2p)
fi
V2RAY_TPROXY_PORT=12345
V2RAY_DNS_PORT=7913
# These sites are V2Ray servers
# We bypass websocket-based v2ray servers
ALLOW_DOMAIN_LIST="ws.example.com ws.example1.com"
# We bypass the following domains for SoftEther to get original IP
ALLOW_DOMAIN_LIST="$ALLOW_DOMAIN_LIST softether-network.net softether.co.jp flets-east.jp flets-west.jp ddns.uxcom.jp"
ALLOW_DOMAIN_LIST="$ALLOW_DOMAIN_LIST plex.tv plex.direct apple.com microsoft.com"
ALLOW_IP_LIST="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4 223.5.5.5 223.6.6.6 114.114.114.114 114.114.115.115 1.2.4.8 210.2.4.8 112.124.47.27 114.215.126.16 180.76.76.76 119.29.29.29"
# These sites are forced using V2ray proxy
BLOCK_IP_LIST=""
BLOCK_DOMAIN_LIST="google.com.tw google.com.ncr github.com github.io raw.githubusercontent.com apnic.net s3.amazonaws.com openwrt.org"
# UPSTREAM/FOREIGN
DNS_PREFERENCE="UPSTREAM"

echo_date() {
  echo "$(date) - $1"
}

install_v2ray() {
	echo_date "Checking V2Ray version"
	latest_version=$(wget --no-check-certificate --timeout=8 -qO- "https://github.com/v2ray/v2ray-core/tags"| grep "/v2ray/v2ray-core/releases/tag/"| head -n 1| awk -F "/tag/" '{print $2}'| sed 's/\">//')
  if [ -z "$latest_version" ]; then
    echo_date "Failed to fetch V2Ray version"
    exit 1
  fi
  echo_date "Downloading V2Ray $latest_version"
  [ -f "$TMP/v2ray.zip" ] && rm "$TMP/v2ray.zip"

  arch=$(uname -m)

  if [ "$arch" = "x86_64" ]; then
    filename="v2ray-linux-64.zip"
  elif [ "$arch" = "mips" ]; then
    filename="v2ray-linux-mips.zip"
  else
    echo "Unsupported arch: $arch"
    exit 1
  fi

  if wget --no-check-certificate \
           --timeout=8 \
           -qO- \
           "https://github.com/v2ray/v2ray-core/releases/download/$latest_version/$filename" > "$TMP/v2ray.zip"; then
    echo_date "Downloaded"
    [ -d "$TMP/v2ray" ] && rm -rf "$TMP/v2ray"
    mkdir -p "$TMP/v2ray"
    echo_date "Unziping..."

    if unzip "$TMP/v2ray.zip" -d "$TMP/v2ray" >/dev/null; then
      [ ! -d "$WORKPLACE/v2ray" ] && mkdir -p "$WORKPLACE/v2ray"
      if [ "$arch" = "x86_64" ]; then
        mv -f "$TMP/v2ray/v2ctl" "$WORKPLACE/v2ray/v2ctl"
        mv -f "$TMP/v2ray/v2ray" "$WORKPLACE/v2ray/v2ray"
      else
        mv -f "$TMP/v2ray/v2ctl_softfloat" "$WORKPLACE/v2ray/v2ctl"
        mv -f "$TMP/v2ray/v2ray_softfloat" "$WORKPLACE/v2ray/v2ray"
      fi
      echo_date "V2Ray installed"
    else
      echo_date "Failed to unzip"
    fi
  else
    echo_date "Failed to download"
    exit 1
  fi
}

wait_v2ray_start() {
  i=2
  while
    i=$((i-1))
    sleep 1
    [ ! "$(pidof v2ray)" ] && [ $i -gt 0 ]
  do :; done

  if [ $i -eq 0 ]; then
    echo_date "Failed to start V2Ray"
    exit 1
  fi
}

wait_v2ray_stop() {
  i=5
  while [ "$(pidof v2ray)" ] && [ $i -gt 0 ]; do
    i=$((i-1))
    sleep 1
  done
  if [ $i -eq 0 ]; then
    echo_date "Failed to stop V2Ray"
    exit 1
  fi
}

start_v2ray() {
  if [ "$(pidof v2ray)" ]; then
    echo_date "V2Ray alreay started"
    exit 1
  fi

  if [ -f "$WORKPLACE/config.json" ]; then
    if [ ! -f "$WORKPLACE/v2ray/v2ray" ]; then
      echo_date "Could not found $WORKPLACE/v2ray/v2ray"
      exit 1
    fi
    ("$WORKPLACE/v2ray/v2ray" -config "$WORKPLACE/config.json" >/dev/null 2>&1 )&
    wait_v2ray_start
    echo_date "V2Ray has been started"
  else
    echo_date "Can not found $WORKPLACE/config.json"
    exit 1
  fi
}

stop_v2ray() {
  pid=$(pidof v2ray)
  if [ "$pid" ]; then
    kill "$pid"
    wait_v2ray_stop
    echo_date "V2Ray has been stopped"
  else
    echo_date "Can not found process of V2Ray"
  fi
}

optimize_network(){
	echo_date "Optimize network"
	cat > /tmp/net_optimized.conf <<-EOF
		fs.file-max = 51200
		net.core.rmem_max = 67108864
		net.core.wmem_max = 67108864
		net.core.rmem_default=65536
		net.core.wmem_default=65536
		net.core.netdev_max_backlog = 4096
		net.core.somaxconn = 4096
		net.ipv4.tcp_syncookies = 1
		net.ipv4.tcp_tw_reuse = 1
		net.ipv4.tcp_tw_recycle = 0
		net.ipv4.tcp_fin_timeout = 30
		net.ipv4.tcp_keepalive_time = 1200
		net.ipv4.ip_local_port_range = 10000 65000
		net.ipv4.tcp_max_syn_backlog = 4096
		net.ipv4.tcp_max_tw_buckets = 5000
		net.ipv4.tcp_fastopen = 3
		net.ipv4.tcp_rmem = 4096 87380 67108864
		net.ipv4.tcp_wmem = 4096 65536 67108864
		net.ipv4.tcp_mtu_probing = 1
	EOF
	sysctl -p /tmp/net_optimized.conf >/dev/null 2>&1
	rm -rf /tmp/net_optimized.conf
}

config_dnsmasq() {
  echo_date "Copy dnsmasq configurations"
  # NOTE: all conf files start with "transproxy_"
  if [ ! -f "$TMP/transproxy_server.conf" ]; then
    echo_date 'Can not found dnsmasq configuration. You should run the script with "--update-rules" first'
    exit 1
  fi

  if [ -d $DNSMASQ_CONF ]; then
    cp -f "$ACCELERATED_DOMAINS_CONF" "$DNSMASQ_CONF/"
    cp -f "$ALLOW_LIST_CONF" "$DNSMASQ_CONF/"
    cp -f "$BLOCK_LIST_CONF" "$DNSMASQ_CONF/"
    cp -f "$DNS_SERVER_CONF" "$DNSMASQ_CONF/"
  else
    echo_date "Can not found $DNSMASQ_CONF"
    exit 1
  fi
}

clean_dnsmasq() {
  echo_date "Remove dnsmasq configurations"
  if [ -d $DNSMASQ_CONF ]; then
    rm -f $DNSMASQ_CONF/transproxy_* >/dev/null 2>&1
  fi
}

restart_dnsmasq() {
	echo_date "Restart dnsmasq"
	/etc/init.d/dnsmasq restart >/dev/null 2>&1
}

update_rules() {
  latest_versions=$(wget --no-check-certificate --timeout=8 -qO- https://raw.githubusercontent.com/pwrliang/OTransproxy/master/rules/version)

  if [ -z "$latest_versions" ]; then
    echo_date "Failed to fetch rules version"
    exit 1
  fi

  if [ ! -f "$TMP/version" ] || [ "$(cat "$TMP/version")" != "$latest_versions" ] || \
     [ ! -f "$TMP/accelerated-domains.china.txt" ] || [ ! -f "$TMP/chnroute.txt" ]; then
    echo_date "Detected rules changed, downloading..."
    if wget --no-check-certificate \
            --timeout=8 \
            -qO- \
            https://raw.githubusercontent.com/pwrliang/OTransproxy/master/rules/accelerated-domains.china.txt >"$TMP/accelerated-domains.china.txt"; then
      echo_date "Generating $ACCELERATED_DOMAINS_CONF"
      sed "s/^/server=&\/./g" < "$TMP/accelerated-domains.china.txt" | sed "s/$/\/&$UPSTREAM_DNS/g" > "$ACCELERATED_DOMAINS_CONF"
    else
      echo_date "Failed to download accelerated-domains.china.txt"
      exit 1
    fi

    if wget --no-check-certificate \
            --timeout=8 \
            -qO- \
            https://raw.githubusercontent.com/pwrliang/OTransproxy/master/rules/chnroute.txt >"$TMP/chnroute.txt"; then
      echo_date "China route list downloaded"
    else
      echo_date "Failed to download China route"
      exit 1
    fi
    echo "$latest_versions" >"$TMP/version"
  fi

  echo "# These domain will be resolved by local dns server" > "$BLOCK_LIST_CONF"
  for domain in $BLOCK_DOMAIN_LIST; do
    echo "$domain" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#$V2RAY_DNS_PORT/g" >> "$BLOCK_LIST_CONF"
    echo "$domain" | sed "s/^/ipset=&\/./g" | sed "s/$/\/BLOCK_SET/g" >> "$BLOCK_LIST_CONF"
  done

  echo "# These domain will be resolved by $UPSTREAM_DNS" > "$ALLOW_LIST_CONF"
  for domain in $ALLOW_DOMAIN_LIST; do
    echo "$domain" | sed "s/^/server=&\/./g" | sed "s/$/\/$UPSTREAM_DNS/g" >> "$ALLOW_LIST_CONF"
    echo "$domain" | sed "s/^/ipset=&\/./g" | sed "s/$/\/ALLOW_SET/g" >> "$ALLOW_LIST_CONF"
  done

  [ ! -f "$DNS_SERVER_CONF" ] && {
    echo "no-resolv" > "$DNS_SERVER_CONF"

    if [ $DNS_PREFERENCE = "UPSTREAM" ]; then
      echo "server=$UPSTREAM_DNS" >> "$DNS_SERVER_CONF"
    elif [ $DNS_PREFERENCE = "FOREIGN" ]; then
      echo "server=127.0.0.1#$V2RAY_DNS_PORT" >> "$DNS_SERVER_CONF"
    else
      echo "Unsupported parameter: $DNS_SERVER_CONF"
      exit 1
    fi
  }
}

flush_nat(){
  iptables -t nat -F V2RAY >/dev/null 2>&1
  ipset -F ALLOW_SET >/dev/null 2>&1
  ipset -F BLOCK_SET >/dev/null 2>&1
}

creat_ipset(){
  echo_date "Creating ipset"
	ipset -! create ALLOW_SET nethash && ipset flush ALLOW_SET
  ipset -! create BLOCK_SET nethash && ipset flush BLOCK_SET
	# 中国IP加入白名单
	sed -e "s/^/add ALLOW_SET &/g" "$TMP/chnroute.txt" | awk '{print $0} END{print "COMMIT"}' | ipset -R

	for ip in $ALLOW_IP_LIST
	do
		ipset -! add ALLOW_SET "$ip" >/dev/null 2>&1
	done

	for ip in $BLOCK_IP_LIST
	do
		ipset -! add BLOCK_SET $ip >/dev/null 2>&1
	done
}

apply_nat_rules(){
  echo_date "Applying iptables"
  # 新建一个名为 V2RAY 的链
  iptables -t nat -N V2RAY >/dev/null 2>&1
  # 直连白名单网站
  iptables -t nat -A V2RAY -p tcp -m set --match-set ALLOW_SET dst -j RETURN
  # 黑名单走代理
  iptables -t nat -A V2RAY -p tcp -m set --match-set BLOCK_SET dst -j REDIRECT --to-ports $V2RAY_TPROXY_PORT
  # 直连 SO_MARK 为 0xff 的流量(0xff 是 16 进制数，数值上等同与上面配置的 255)，此规则目的是避免代理本机(网关)流量出现回环问题
  iptables -t nat -A V2RAY -p tcp -j RETURN -m mark --mark 0xff
  # 其余流量转发到 12345 端口（即 V2Ray）
  iptables -t nat -A V2RAY -p tcp -j REDIRECT --to-ports $V2RAY_TPROXY_PORT
  # 对局域网其他设备进行透明代理
  iptables -t nat -A PREROUTING -p tcp -j V2RAY
  # 对本机进行透明代理
  iptables -t nat -A OUTPUT -p tcp -j V2RAY
}

load_nat() {
  flush_nat
  creat_ipset
  apply_nat_rules
}

start_service() {
  start_v2ray
  config_dnsmasq
  restart_dnsmasq
  load_nat
  optimize_network
}

stop_service() {
  clean_dnsmasq
  restart_dnsmasq
  flush_nat
  stop_v2ray
}

main() {
  mkdir -p "$WORKPLACE" >/dev/null 2>&1
  mkdir -p "$TMP" >/dev/null 2>&1
  case $1 in

  "--install")
    install_v2ray
    update_rules
    ;;
  "--start")
    start_service
    ;;
  "--stop")
    stop_service
    ;;
  "--restart")
    stop_service
    start_service
    ;;
  "--update-rules")
    update_rules
    clean_dnsmasq
    config_dnsmasq
    restart_dnsmasq
    ;;
  *)
    echo "A script auto config transproxy."
    echo "options:"
    echo "  --install: Install v2ray and download rules"
    echo "  --start: Start V2RAY and config transproxy"
    echo "  --stop: Stop V2RAY and flush transproxy"
    echo "  --restart: restart is an alise of --stop & --start"
    echo "  --update-rules: Download rules"
    echo "  NOTE: You should put config.json under $WORKPLACE"
    ;;
  esac
}

main "$@"
