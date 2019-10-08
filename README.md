# OTransproxy
OTransproxy stands for a transparent proxy on OpenWrt. OTransproxy is a simple script to implement a transparent proxy. [V2Ray](https://github.com/v2ray/v2ray-core) is used as the back-end proxy software.
It forwards foreign network traffic to your V2Ray server, but bypass the local (Chinese sites) traffic. You can also choose which site to bypass/proxy by
simply modify the script. **My intention in writing this script is to learning shell programming skill. Using at your own risk.**


## Typical usage
### Install
1. Download the OTransproxy and configurations:
```sh
mkdir -p /opt/OTransproxy && \
cd /opt/OTransproxy && \
wget -q https://raw.githubusercontent.com/pwrliang/OTransproxy/master/otransproxy.sh && \
wget -q https://raw.githubusercontent.com/pwrliang/OTransproxy/master/config.json && \
wget -q https://raw.githubusercontent.com/pwrliang/OTransproxy/master/bypass.list && \
wget -q https://raw.githubusercontent.com/pwrliang/OTransproxy/master/proxy.list && \
chmod +x otransproxy.sh
```
2. Custom you own config.json of V2Ray. Fill your IPs/domains of V2Ray servers into `bypass.list`, otherwise it causes **INFINITELY** proxy.
3. `./otransproxy.sh --install` This step will download V2Ray binaries and rules.
4. `./otransproxy.sh --start`  This step will start V2Ray and configure iptables and dnsmasq.
5. `./otransproxy.sh --enable` This step will startup OTransproxy service when system up.
 
Now you are good to go. You can run `curl https://google.com` to test the network connectivity.
### Uninstall
OTransproxy will not dirty your system. You can easily run the following commands to remove it. 
1. `/opt/OTransproxy/otransproxy.sh --stop`
2. `/opt/OTransproxy/otransproxy.sh --disable`
3. `rm -rf /opt/OTransproxy`
### Update rules automatically
The following operation implements update rules atomically at 5 A.M. for every day.
1. `crontab -e`
2. append `0 5 * * * /opt/OTransproxy/otransproxy.sh --update-rules`
### Sample output
```sh
```
---
## Note 
- **Only tested and works on following platforms: Koolshare x86_64, OpenWrt mips**
- **The config.json, bypass.list and proxy.list must be putted with otransproxy.sh under the same location.**
- **Requirements: dnsmasq, iptables, ipset.**
- **You must add your IPs/domains of V2Ray servers into bypass.list to avoid infinitely proxy.**
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
