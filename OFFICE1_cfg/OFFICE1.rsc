# jan/23/2023 09:44:31 by RouterOS 6.48.6
#
# model = RB2011UiAS
/interface bridge
add comment="respond to ARP requests originating from same-subnet road warriors through VPN" arp=proxy-arp name=bridge.LAN
/interface ethernet
set [ find default-name=ether1 ] name=ether1.wisp.static.main
set [ find default-name=ether2 ] name=ether2.adsl.PPPoE.backup
set [ find default-name=sfp1 ] disabled=yes
/interface pppoe-client
add disabled=no interface=ether2.adsl.PPPoE.backup name=\
    pppoe-out.adsl.PPPoE.backup use-peer-dns=yes user=\
    adsl_user@isp.com
/interface list
add name=LAN
/ip ipsec peer
add address=192.0.2.100/32 exchange-mode=ike2 name=Office2_peer
add address=192.0.2.200/32 comment="waits for initial contact from the peer at Office2 backup WAN" \
    disabled=yes exchange-mode=ike2 name=Office2_peer_backup send-initial-contact=\
    no
add address=198.51.100.100/32 exchange-mode=ike2 name=Office3_peer
/ip ipsec profile
set [ find default=yes ] dh-group=modp4096 dpd-interval=10s \
    dpd-maximum-failures=1 enc-algorithm=aes-256 hash-algorithm=sha256 \
    lifetime=1h
/ip ipsec proposal
set [ find default=yes ] auth-algorithms=sha256 enc-algorithms=aes-256-gcm \
    pfs-group=modp4096
/ip pool
add name=dhcp_pool0 ranges=172.17.0.101-172.17.255.254
/ip dhcp-server
add address-pool=dhcp_pool0 disabled=no interface=bridge.LAN name=dhcp1
/ppp profile
add change-tcp-mss=yes dns-server=8.8.8.8,1.1.1.1 local-address=172.17.0.100 \
    name=office1-pptp-profile only-one=yes use-encryption=yes use-upnp=no
/user group
add name=api_user_grafana policy="read,test,api,!local,!telnet,!ssh,!ftp,!rebo\
    ot,!write,!policy,!winbox,!password,!web,!sniff,!sensitive,!romon,!dude,!t\
    ikapp"
add name=backup_user policy="ssh,!local,!telnet,!ftp,!reboot,!read,!write,!pol\
    icy,!test,!winbox,!password,!web,!sniff,!sensitive,!api,!romon,!dude,!tika\
    pp"
/interface bridge port
add bridge=bridge.LAN interface=ether3
add bridge=bridge.LAN interface=ether4
add bridge=bridge.LAN interface=ether5
add bridge=bridge.LAN interface=ether6
add bridge=bridge.LAN interface=ether7
add bridge=bridge.LAN interface=ether8
add bridge=bridge.LAN interface=ether9
add bridge=bridge.LAN interface=ether10
/ip neighbor discovery-settings
set discover-interface-list=LAN
/interface list member
add interface=bridge.LAN list=LAN
/interface pptp-server server
set authentication=mschap2 default-profile=office1-pptp-profile enabled=yes
/ip address
add address=172.17.0.100/16 interface=bridge.LAN network=172.17.0.0
add address=203.0.113.100/30 interface=ether1.wisp.static.main network=\
    203.0.113.99
/ip dhcp-server lease
add address=172.17.0.101 client-id=1:aa:bb:cc:dd:ee:ff comment=\
    "CUPS print server example host" mac-address=AA:BB:CC:DD:EE:FF server=dhcp1
/ip dhcp-server network
add address=172.17.0.0/16 gateway=172.17.0.100
/ip dns
set allow-remote-requests=yes servers=198.51.100.10,198.51.100.20
/ip firewall address-list
add address=198.51.100.30 list=cups
/ip firewall filter
add action=drop chain=output comment="cloud service1 unreachable failover test when enabled" disabled=\
    yes dst-address=198.51.100.40
add action=drop chain=output comment="cloud service2 unreachable failover test when enabled" \
    disabled=yes dst-address=198.51.100.30
add action=accept chain=input connection-state=established,related
add action=accept chain=input comment=\
    "ICMP accepted (router responds to pings externally)" protocol=icmp
add action=accept chain=input comment="accept winbox mgmt connections on a custom port" dst-port=28291 \
    protocol=tcp
add action=accept chain=input comment=\
    "accept API requests from the telegraf agent running on cloud service 1" \
    dst-port=28729 protocol=tcp src-address=198.51.100.30
add action=drop chain=input comment="drop blacklisted source IPs doing potential ssh bruteforce attack\
    probes, except cloud service 1" dst-port=22022 protocol=tcp \
    src-address=!198.51.100.30 src-address-list=ssh_blacklist
add action=add-src-to-address-list address-list=ssh_blacklist \
    address-list-timeout=1w3d chain=input comment=\
    "3. ssh bruteforce ban listing(10d)" connection-state=new dst-port=22022 \
    protocol=tcp src-address-list=ssh_stage2
add action=add-src-to-address-list address-list=ssh_stage2 \
    address-list-timeout=3s chain=input comment=\
    "2. ssh bruteforce pre-selection, stage2(3sec)" connection-state=new \
    disabled=yes dst-port=22022 protocol=tcp src-address-list=ssh_stage1
add action=add-src-to-address-list address-list=ssh_stage1 \
    address-list-timeout=4h chain=input comment=\
    "1. ssh bruteforce pre-selection, stage1(4h)" connection-state=new \
    dst-port=22022 protocol=tcp
add action=accept chain=input comment="ssh accepted" dst-port=22022 \
    protocol=tcp
add action=accept chain=input comment="IKE2/IPSec port accepted" dst-port=\
    500 protocol=udp
add action=accept chain=input comment="IKE2/IPSec NAT port accepted" \
    dst-port=4500 protocol=udp
add action=accept chain=input comment=\
    "IPSec encapsulation protocol accepted on the main WAN" in-interface=\
    ether1.wisp.static.main protocol=ipsec-esp
add action=accept chain=input comment=\
    "IPSec encapsulation protocol accepted on the backup WAN" \
    in-interface=pppoe-out.adsl.PPPoE.backup protocol=ipsec-esp
add action=accept chain=forward comment=\
    "IPSec traffic forwarding accepted from Office2 subnet" src-address=\
    172.18.0.0/16
add action=accept chain=forward comment=\
    "IPSec traffic forwarding accepted from Office3 subnet" src-address=\
    172.19.0.0/16
add action=drop chain=input comment=\
    "drop blacklisted source IPs doing potential PPTP bruteforce attack probes" \
    protocol=tcp dst-port=1723 src-address-list=pptp_blacklist
add action=add-src-to-address-list address-list=pptp_blacklist \
    address-list-timeout=1w3d chain=input comment=\
    "3. PPTP bruteforce ban listing(10d)" \
    protocol=tcp dst-port=1723 connection-state=new \
    src-address-list=pptp_stage2
add action=add-src-to-address-list address-list=pptp_stage2 \
    address-list-timeout=1m chain=input comment=\
    "2. PPTP bruteforce pre-selection, stage2(1min)" \
    protocol=tcp dst-port=1723 connection-state=new \
    src-address-list=pptp_stage1
add action=add-src-to-address-list address-list=pptp_stage1 \
    address-list-timeout=1h chain=input comment=\
    "1. PPTP bruteforce pre-selection, stage1(1h)" \
    protocol=tcp dst-port=1723 connection-state=new
add action=accept chain=input comment="PPTP accepted" dst-port=1723 \
    protocol=tcp
add action=accept chain=input comment="GRE protocol accepted" protocol=\
    gre
add action=drop chain=input comment="implicit deny everything else!!!" \
    in-interface=!bridge.LAN
/ip firewall mangle
add action=change-mss chain=forward disabled=yes new-mss=1440 out-interface=\
    pppoe-out.adsl.PPPoE.backup passthrough=yes protocol=tcp tcp-flags=\
    syn tcp-mss=1441-65535
add action=change-mss chain=forward disabled=yes new-mss=clamp-to-pmtu \
    out-interface=pppoe-out.adsl.PPPoE.backup passthrough=yes protocol=\
    tcp tcp-flags=syn
add action=change-mss chain=forward disabled=yes in-interface=\
    pppoe-out.adsl.PPPoE.backup new-mss=1440 passthrough=yes protocol=\
    tcp tcp-flags=syn tcp-mss=1441-65535
add action=change-mss chain=forward disabled=yes in-interface=\
    pppoe-out.adsl.PPPoE.backup new-mss=clamp-to-pmtu passthrough=yes \
    protocol=tcp tcp-flags=syn
/ip firewall nat
add action=accept chain=srcnat comment="IPSec bypass towards Office2" dst-address=172.18.0.0/16 src-address=\
    172.17.0.0/16
add action=accept chain=srcnat comment="IPSec bypass towards Office3" dst-address=172.19.0.0/16 src-address=\
    172.17.0.0/16
add action=masquerade chain=srcnat comment="main WAN NAT" out-interface=ether1.wisp.static.main
# pppoe-out.adsl.PPPoE.backup not ready
add action=masquerade chain=srcnat comment="backup WAN NAT" out-interface=\
    pppoe-out.adsl.PPPoE.backup
add action=dst-nat chain=dstnat comment="CUPS print server SSH port forward example" dst-port=22222 \
    protocol=tcp src-address-list=cups to-addresses=172.17.0.101 to-ports=22
add action=dst-nat chain=dstnat comment="CUPS print server WEBIF port forward example" dst-port=22631 \
    protocol=tcp src-address-list=cups to-addresses=172.17.0.101 to-ports=\
    631
/ip firewall raw
add chain=prerouting action=notrack protocol=ipsec-esp \
    comment="Bypass conntrack for IPSec ESP traffic to prevent stale sessions blocking tunnel re-establishment after WAN failover"
/ip ipsec identity
add peer=Office3_peer
add peer=Office2_peer
add comment=backup disabled=yes peer=Office2_peer_backup
/ip ipsec policy
add dst-address=172.19.0.0/16 peer=Office3_peer src-address=172.17.0.0/16 \
    tunnel=yes
add dst-address=172.18.0.0/16 peer=Office2_peer src-address=172.17.0.0/16 \
    tunnel=yes
add comment=backup disabled=yes dst-address=172.18.0.0/16 peer=Office2_peer_backup \
    src-address=172.17.0.0/16 tunnel=yes
/ip route
add comment="static route: main WISP" distance=1 gateway=203.0.113.101
add comment="static route: backup ADSL" distance=2 gateway=\
    pppoe-out.adsl.PPPoE.backup
add comment="Is cloud service1 reachable through ADSL backup WAN\?" \
    disabled=yes distance=1 dst-address=198.51.100.30/32 gateway=\
    pppoe-out.adsl.PPPoE.backup
add check-gateway=ping comment="Is cloud service2 reachable through the main WISP WAN\?" \
    distance=1 dst-address=198.51.100.40/32 gateway=203.0.113.101
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=22022
set api disabled=yes
set winbox port=28291
set api-ssl address=198.51.100.30/32 certificate=Office1_rosAPI_crt port=\
    28729
/ip ssh
set forwarding-enabled=both
/lcd
set default-screen=stats read-only-mode=yes
/lcd interface
set sfp1 disabled=yes
/lcd interface pages
set 0 interfaces="ether1.wisp.static.main,ether2.adsl.PPPoE.backup,et\
    her3,ether4,ether5,ether6,ether7,ether8,ether9,ether10"
/ppp secret
add name=roadwarrior1 profile=office1-pptp-profile remote-address=172.17.0.14 \
    service=pptp
add name=roadwarrior2 profile=office1-pptp-profile remote-address=172.17.0.13 \
    service=pptp
/system clock
set time-zone-autodetect=no time-zone-name=Europe/Budapest
/system identity
set name=Office1_router
/system logging
add disabled=yes prefix=ipsec topics=ipsec
add topics=interface
/system ntp client
set enabled=yes server-dns-names=hu.pool.ntp.org
/system package update
set channel=long-term
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
/tool netwatch
add comment="watch cloud service2 on the main WISP WAN and disable it's static\
    route when it becomes unreachable, then change DNS servers, clear DNS cache,\
    remove stale connections and failover to backup ADSL WAN" down-script="/ip \
    route disable [find comment=\"static route: main WISP\"]\r\
    \n:log error \"main staticIP WAN NOT OK, changing to backup ADSL"\r\
    \n/ip firewall connection remove [find]\r\
    \n/ip dns set servers=\"198.51.100.240,198.51.100.250\"\r\
    \n/ip dns cache flush" host=198.51.100.40 interval=10s timeout=3s \
    up-script="/ip route enable [find comment=\"static route: main WISP\"]\
    \r\
    \n:log error \"main staticIP WAN OK, changing back from backup ADSL\
    \"\r\
    \n/ip firewall connection remove [find]\r\
    \n/ip dns set servers=\"198.51.100.10,198.51.100.20\"\r\
    \n/ip dns cache flush"
add comment="watch and log Office2 router" down-script=\
    ":log error \"Office2 router unreachable\"" host=192.0.2.100 interval=\
    10s up-script=":log error \"Office2 router reachable\""
add comment="watch and log Office3 router" down-script=\
    ":log error \"Office3 router unreachable\"" host=198.51.100.100 \
    interval=10s up-script=":log error \"Office3 router reachable\""
add comment="watch and log cloud service2" down-script=\
    ":log error \"cloud service2 unreachable\"" host=198.51.100.40 interval=10s \
    up-script=":log error \"cloud service2 reachable\""
/tool sniffer
set filter-interface=bridge.LAN filter-port=bootpc
