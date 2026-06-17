# jan/23/2023 09:56:35 by RouterOS 6.48.6
#
# model = RB2011UiAS
/interface bridge
add comment="respond to ARP requests originating from same-subnet road warriors through VPN" arp=proxy-arp name=bridge.LAN
/interface ethernet
set [ find default-name=ether1 ] name=ether1.wisp.PPPoE.main
set [ find default-name=ether2 ] disabled=yes name=ether2.backup.unused
set [ find default-name=sfp1 ] disabled=yes
/interface pppoe-client
add add-default-route=yes disabled=no interface=\
    ether1.wisp.PPPoE.main name=pppoe-out.wisp.PPPoE.main \
    use-peer-dns=yes user=wisp_user@isp.com
/interface list
add name=LAN
/interface lte apn
set [ find default=yes ] ip-type=ipv4-ipv6
/ip ipsec peer
add address=192.0.2.100/32 exchange-mode=ike2 name=Office2_peer
add address=192.0.2.200/32 comment="waits for initial contact from the peer at Office2 backup WAN" \
    disabled=yes exchange-mode=ike2 name=Office2_peer_backup send-initial-contact=\
    no
add address=203.0.113.100/32 exchange-mode=ike2 name=Office1_peer
/ip ipsec profile
set [ find default=yes ] dh-group=modp4096 dpd-interval=3s \
    dpd-maximum-failures=1 enc-algorithm=aes-256 hash-algorithm=sha256 \
    lifetime=1h
/ip ipsec proposal
set [ find default=yes ] auth-algorithms=sha256 enc-algorithms=aes-256-gcm \
    pfs-group=modp4096
/ip pool
add name=dhcp_pool0 ranges=172.19.0.101-172.19.255.254
/ip dhcp-server
add address-pool=dhcp_pool0 disabled=no interface=bridge.LAN name=dhcp.LAN
/ppp profile
add dns-server=8.8.8.8,1.1.1.1 local-address=172.19.0.100 name=office3-pptp-profile \
    only-one=yes use-encryption=yes use-upnp=no wins-server=8.8.4.4
/user group
add name=api_user_grafana policy="read,test,api,!local,!telnet,!ssh,!ftp,!rebo\
    ot,!write,!policy,!winbox,!password,!web,!sniff,!sensitive,!romon,!dude,!t\
    ikapp"
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
/ip settings
set max-neighbor-entries=4096
/interface list member
add interface=bridge.LAN list=LAN
/interface pptp-server server
set authentication=mschap2 default-profile=office3-pptp-profile
/ip address
add address=172.19.0.1/16 interface=bridge.LAN network=172.19.0.0
/ip dhcp-server lease
add address=172.19.0.101 comment="CUPS print server example host" mac-address=\
    AA:BB:CC:DD:EE:FF server=dhcp.LAN
/ip dhcp-server network
add address=172.19.0.0/16 gateway=172.19.0.100
/ip dns
set allow-remote-requests=yes
/ip firewall address-list
add address=198.51.100.30 list=cups
/ip firewall filter
add action=drop chain=output comment="cloud service1 unreachable failover test when enabled" disabled=\
    yes dst-address=198.51.100.40
add action=drop chain=output comment="cloud service2 unreachable failover test when enabled" \
    disabled=yes dst-address=198.51.100.30
add action=accept chain=input comment=\
    "everything already established or related" connection-state=\
    established,related
add action=accept chain=input comment=\
    "ICMP accepted (router responds to pings externally)" protocol=icmp
add action=accept chain=input comment="accept winbox mgmt connections on a custom port" dst-port=28291 \
    protocol=tcp
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
add action=accept chain=input comment=\
    "accept API requests from the telegraf agent running on cloud service 1" \
    dst-port=28729 protocol=tcp src-address=198.51.100.30
add action=accept chain=input comment="IKE2/IPSec port accepted" dst-port=\
    500 protocol=udp
add action=accept chain=input comment="IKE2/IPSec NAT port accepted" \
    dst-port=4500 protocol=udp
add action=accept chain=input comment=\
    "IPSec encapsulation protocol accepted on the main WAN" \
    in-interface=pppoe-out.wisp.PPPoE.main protocol=ipsec-esp
add action=accept chain=forward comment=\
    "IPSec traffic forwarding accepted from Office1 subnet" src-address=\
    172.17.0.0/16
add action=accept chain=forward comment=\
    "IPSec traffic forwarding accepted from Office2 subnet" src-address=\
    172.18.0.0/16
/ip firewall filter
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
add action=drop chain=input comment="implicit deny on everything else!!!" \
    in-interface=!bridge.LAN
/ip firewall nat
add action=accept chain=srcnat comment="IPSec bypass towards Office1" \
    dst-address=172.17.0.0/16 src-address=172.18.0.0/16
add action=accept chain=srcnat comment="IPSec bypass towards Office2" \
    dst-address=172.18.0.0/16 src-address=172.17.0.0/16
add action=masquerade chain=srcnat comment="single WAN NAT" \
    out-interface=pppoe-out.wisp.PPPoE.main
add action=dst-nat chain=dstnat comment="CUPS print server SSH port forward example" dst-port=22222 \
    protocol=tcp src-address-list=cups to-addresses=172.19.0.101 to-ports=22
add action=dst-nat chain=dstnat comment="CUPS print server WEBIF port forward example" dst-port=22631 \
    protocol=tcp src-address-list=cups to-addresses=172.19.0.101 to-ports=\
    631
/ip firewall raw
add chain=prerouting action=notrack protocol=ipsec-esp \
    comment="Bypass conntrack for IPSec ESP traffic to prevent stale sessions blocking tunnel re-establishment after WAN failover"
/ip ipsec identity
add peer=Office1_peer
add peer=Office2_peer
add comment=backup disabled=yes peer=Office2_peer_backup
/ip ipsec policy
add dst-address=172.17.0.0/16 peer=Office1_peer src-address=172.19.0.0/16 \
    tunnel=yes
add dst-address=172.18.0.0/16 peer=Office2_peer src-address=172.19.0.0/16 tunnel=\
    yes
add comment=backup disabled=yes dst-address=172.18.0.0/16 peer=Office2_peer_backup \
    src-address=172.19.0.0/16 tunnel=yes
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=22022
set api disabled=yes
set winbox port=28291
set api-ssl address=198.51.100.30/32 certificate=Office3_rosAPI_crt port=\
    28729
/lcd
set default-screen=stats read-only-mode=yes
/lcd interface
set sfp1 disabled=yes
set ether2.backup.unused disabled=yes
/lcd interface pages
set 0 interfaces="ether1.wisp.PPPoE.main,ether3,ether4,ether5,ether6,\
    ether7,ether8,ether9,ether10"
/ppp secret
add disabled=yes name=roadwarrior1 profile=office3-pptp-profile remote-address=\
    172.19.0.99 service=pptp
/system clock
set time-zone-autodetect=no time-zone-name=Europe/Budapest
/system identity
set name=Office3_router
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
add comment="watch and log Office2 router" down-script=\
    ":log error \"Office2 router unreachable\"" host=192.0.2.100 interval=\
    10s up-script=":log error \"Office2 router reachable\""
add comment="watch and log Office1 router" down-script=\
    ":log error \"Office2 router unreachable\"" host=203.0.113.100 interval=\
    10s up-script=":log error \"Office2 router reachable\""
