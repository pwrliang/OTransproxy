# OTransproxy
OTransproxy stands for a transparent proxy on OpenWrt. OTransproxy is a simple script to implement a transparent proxy. [V2Ray](https://github.com/v2ray/v2ray-core) is used as the back-end proxy software.
It forwards foreign network traffic to your V2Ray server, but bypass the local (Chinese sites) traffic. You can also choose which site to bypass/proxy by
simply modify the script. **My intention in writing this script is to learning shell programming skill. Using at your own risk.**


## Typical usage
### Install
1. `mkdir -p /opt/OTransproxy && cd /opt/OTransproxy && wget https://raw.githubusercontent.com/pwrliang/OTransproxy/master/otransproxy.sh && chmod +x otransproxy.sh`
2. `wget https://raw.githubusercontent.com/pwrliang/OTransproxy/master/config.json && https://raw.githubusercontent.com/pwrliang/OTransproxy/master/bypass.list && https://raw.githubusercontent.com/pwrliang/OTransproxy/master/proxy.list` and custom it 
**(OR you can copy your own config.json to /opt/OTransproxy)**
3. `vi otransproxy.sh` and then, fill your own V2Ray server IPs/domains into WHITE_IP_LIST/WHITE_DOMAIN_LIST 
**(otherwise your domain will be resolved INFINITELY)**
4. `./otransproxy.sh --install` This step will download V2Ray and bypass rules.
5. `./otransproxy.sh --start`  This step will start V2Ray and configure iptables and dnsmasq.

Now you are good to go. You can run `curl https://google.com` to test the network connectivity.
### Uninstall
OTransproxy will not dirty your system. You can easily run the following commands to remove it. 
1. `/opt/OTransproxy/otransproxy.sh --stop`
2. `/etc/init.d/otransproxy disable`
3. `rm -rf /opt/OTransproxy`
4. `rm /etc/init.d/otransproxy`
### Auto start OTransproxy
1. `vi /etc/init.d/otransproxy` and paste the following statements into.
```
#!/bin/sh /etc/rc.common
# The script to start OTransproxy service
# Copyright (C) 2007 OpenWrt.org

START=99
STOP=99

start() {
    /opt/OTransproxy/otransproxy.sh --start >> /opt/OTransproxy/log/otransparent.log
}

stop() {
    /opt/OTransproxy/otransproxy.sh --stop >> /opt/OTransproxy/log/otransparent.log
}
```
2. `chmod +x /etc/init.d/otransproxy`
3. `/etc/init.d/otransproxy enable`
### Update rules automatically
The following operation implements update rules atomically at 5 A.M. for every day.
1. `crontab -e`
2. paste `0 5 * * * /opt/OTransproxy/otransproxy.sh --update-rules` and save
### Sample output
```sh
root@GL-AR750:/# mkdir -p /opt/OTransproxy && cd /opt/OTransproxy
root@GL-AR750:/opt/OTransproxy# wget https://raw.githubusercontent.com/pwrliang/OTransproxy/master/otransproxy.sh && chmod +x otransproxy.sh
Downloading 'https://raw.githubusercontent.com/pwrliang/OTransproxy/master/otransproxy.sh'
Connecting to 151.101.0.133:443
Writing to 'otransproxy.sh'
otransproxy.sh       100% |*******************************| 10570   0:00:00 ETA
Download completed (10570 bytes)
root@GL-AR750:/opt/OTransproxy# vi config.sh
root@GL-AR750:/opt/OTransproxy# vi otransproxy.sh
root@GL-AR750:/opt/OTransproxy# ./otransproxy.sh --install
Sun Sep 22 11:55:52 UTC 2019 - Checking V2Ray version
Sun Sep 22 11:56:03 UTC 2019 - Downloading V2Ray v4.20.0
Sun Sep 22 12:03:35 UTC 2019 - Downloaded
Sun Sep 22 12:03:35 UTC 2019 - Unziping...
Sun Sep 22 12:03:56 UTC 2019 - V2Ray installed
Sun Sep 22 12:03:59 UTC 2019 - Detected rules changed, downloading...
Sun Sep 22 12:04:21 UTC 2019 - Generating ./tmp/transproxy_accelerated_domains.conf
Sun Sep 22 12:04:41 UTC 2019 - China route list downloaded
root@GL-AR750:/opt/OTransproxy# ./otransproxy.sh --start
Sun Sep 22 12:13:22 UTC 2019 - V2Ray has been started
Sun Sep 22 12:13:22 UTC 2019 - Copy dnsmasq configurations
Sun Sep 22 12:13:22 UTC 2019 - Restart dnsmasq
Sun Sep 22 12:13:24 UTC 2019 - Creating ipset
Sun Sep 22 12:13:26 UTC 2019 - Applying iptables
Sun Sep 22 12:13:26 UTC 2019 - Optimize network
root@GL-AR750:/opt/OTransproxy# curl https://google.com
<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="https://www.google.com/">here</A>.
</BODY></HTML>
```
---
## Note 
- **Only tested and works on following platforms: Koolshare x86_64, OpenWrt mips**
- **The config.json must be putted with otransproxy.sh under the same location.**
- **Requirements: dnsmasq, iptables, ipset.**
- **You may change some settings in the otransproxy.sh. 
For example, you must put you the IPs/domains of V2Ray server in the WHITE_IP_LIST/WHITE_DOMAIN_LIST.**
- **The script will try to parse the configuration of dnsmasq under the `/tmp/resolv.conf.auto` to get the upstream DNS server. 
If the file does not exist, 192.168.1.1 will be used as upstream DNS server.**
- **You must append the following JSON for each outbound. This prevents iptables forward the network traffic infinitely.**
```json
    "streamSettings": {
        "sockopt": {
          "mark": 255
        }
      } 
```
- **Currently, OTransproxy only supports forwarding TCP traffic.**
