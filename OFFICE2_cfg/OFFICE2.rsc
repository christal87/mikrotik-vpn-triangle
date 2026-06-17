# jan/23/2023 09:34:03 by RouterOS 6.48.6
#
# model = RB4011iGS+
/interface bridge
add comment="respond to ARP requests originating from same-subnet road warriors through VPN" arp=proxy-arp name=bridge.LAN
/interface ethernet
set [ find default-name=ether1 ] name=ether1.wisp.PPPoE.main
set [ find default-name=ether2 ] name=ether2.adsl.PPPoE.backup
set [ find default-name=sfp-sfpplus1 ] disabled=yes
/interface pppoe-client
add disabled=no interface=ether2.adsl.PPPoE.backup name=pppoe-out.adsl.PPPoE.backup \
    use-peer-dns=yes user= adsl_user@isp.com
add disabled=no interface=ether1.wisp.PPPoE.main name=pppoe-out.wisp.PPPoE.main \
    use-peer-dns=yes user=wisp_user@isp.com
/interface ethernet switch port
set 0 default-vlan-id=0
set 1 default-vlan-id=0
set 2 default-vlan-id=0
set 3 default-vlan-id=0
set 4 default-vlan-id=0
set 5 default-vlan-id=0
set 6 default-vlan-id=0
set 7 default-vlan-id=0
set 8 default-vlan-id=0
set 9 default-vlan-id=0
set 10 default-vlan-id=0
set 11 default-vlan-id=0
/interface list
add name=LAN
/ip ipsec peer
add address=198.51.100.100/32 exchange-mode=ike2 name=Office3_peer
add address=203.0.113.100/32 exchange-mode=ike2 name=Office1_peer
/ip ipsec profile
set [ find default=yes ] dh-group=modp4096 dpd-interval=3s \
    dpd-maximum-failures=1 enc-algorithm=aes-256 hash-algorithm=sha256 \
    lifetime=1h
/ip ipsec proposal
set [ find default=yes ] auth-algorithms=sha256 enc-algorithms=aes-256-gcm \
    pfs-group=modp4096
/ip pool
add name=dhcp_pool0 ranges=172.18.0.101-172.18.255.254
/ip dhcp-server
add address-pool=dhcp_pool0 disabled=no interface=bridge.LAN name=dhcp.LAN
/ppp profile
add change-tcp-mss=yes dns-server=8.8.8.8,1.1.1.1 local-address=172.18.0.100 \
    name=office2-pptp-profile only-one=yes use-encryption=yes
/snmp community
set [ find default=yes ] disabled=yes
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
/interface list member
add interface=bridge.LAN list=LAN
/interface pptp-server server
set authentication=mschap2 default-profile=office2-pptp-profile enabled=yes
/ip address
add address=172.18.0.100/16 interface=bridge.LAN network=172.18.0.0
/ip dhcp-server lease
add address=172.18.0.109 comment=roadwarrior1-pptp mac-address=1A:BB:CC:DD:EE:FF
add address=172.18.0.110 comment=roadwarrior2-pptp mac-address=2A:BB:CC:DD:EE:FF
add address=172.18.0.101 comment="CUPS print server example host" mac-address=\
    AA:BB:CC:DD:EE:FF server=dhcp.LAN
/ip dhcp-server network
add address=172.18.0.0/16 gateway=172.18.0.100
/ip dns
set allow-remote-requests=yes
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
    "IPSec encapsulation protocol accepted on the main WAN" \
    in-interface=pppoe-out.wisp.PPPoE.main protocol=ipsec-esp
add action=accept chain=input comment=\
    "IPSec encapsulation protocol accepted on the backup WAN" \
    in-interface=pppoe-out.adsl.PPPoE.backup protocol=ipsec-esp
add action=accept chain=forward comment=\
    "IPSec traffic forwarding accepted from Office1 subnet" src-address=\
    172.17.0.0/16
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
/ip firewall nat
add action=accept chain=srcnat comment="IPSec bypass towards Office1" \
    dst-address=172.17.0.0/16 src-address=172.18.0.0/16
add action=accept chain=srcnat comment="IPSec bypass towards Office3" \
    dst-address=172.19.0.0/16 src-address=172.18.0.0/16
add action=masquerade chain=srcnat comment="main WAN NAT" \
    out-interface=pppoe-out.wisp.PPPoE.main
add action=masquerade chain=srcnat comment="backup WAN NAT" \
    out-interface=pppoe-out.adsl.PPPoE.backup
add action=dst-nat chain=dstnat comment="CUPS print server SSH port forward example" dst-port=22222 \
    protocol=tcp src-address-list=cups to-addresses=172.18.0.101 to-ports=22
add action=dst-nat chain=dstnat comment="CUPS print server WEBIF port forward example" dst-port=22631 \
    protocol=tcp src-address-list=cups to-addresses=172.18.0.101 to-ports=\
    631
/ip firewall raw
add chain=prerouting action=notrack protocol=ipsec-esp \
    comment="Bypass conntrack for IPSec ESP traffic to prevent stale sessions blocking tunnel re-establishment after WAN failover"
/ip ipsec identity
add peer=Office1_peer
add peer=Office3_peer
/ip ipsec policy
add dst-address=172.17.0.0/16 peer=Office1_peer src-address=172.18.0.0/16 \
    tunnel=yes
add dst-address=172.19.0.0/16 peer=Office3_peer src-address=172.18.0.0/16 \
    tunnel=yes
/ip route
add check-gateway=ping comment="static route: main WISP" distance=1 gateway=\
    pppoe-out.wisp.PPPoE.main
add comment="static route: backup ADSL" distance=2 gateway=\
    pppoe-out.adsl.PPPoE.backup
add comment="Is cloud service1 reachable through ADSL backup WAN\?" disabled=yes \
    distance=1 dst-address=198.51.100.30/32 gateway=\
    pppoe-out.adsl.PPPoE.backup
add check-gateway=ping comment="Is cloud service2 reachable through the main WISP WAN\?" distance=\
    1 dst-address=198.51.100.40/32 gateway=pppoe-out.wisp.PPPoE.main
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh port=22022
set api disabled=yes
set winbox port=28291
set api-ssl address=198.51.100.30/32 certificate=Office2_rosAPI_crt port=\
    28729
/ppp secret
add name=roadwarrior2 profile=office2-pptp-profile remote-address=172.18.0.110 service=\
    pptp
add name=roadwarrior1 profile=office2-pptp-profile remote-address=172.18.0.109 \
    service=pptp
/snmp
set location=O2 trap-generators=interfaces trap-version=3
/system clock
set time-zone-autodetect=no time-zone-name=Europe/Budapest
/system identity
set name=Office2_router
/system logging
add disabled=yes prefix=ipsec topics=ipsec
add topics=interface
/system note
set note="Note to other sysadmins: this router uses ether1 to reach the internet\
    through a PPPoE connection which serves as the main ISP. This is observed\
    through netwatch checking cloud service 2. Once this fails a script changes\
    the default route to ether2, which serves as the backup ISP (PPPoE through ADSL).\
    It also clears the connection tracking table and switches DNS servers if neccesary.\
    This router keeps a constant IKE2/PISec L3 tunnel with Offices 1 and 3. Plus\
    there's a port forward for a key web service."
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
add comment="watch and log Office1 router" down-script=\
    ":log error \"Office2 router unreachable\"" host=203.0.113.100 interval=\
    10s up-script=":log error \"Office2 router reachable\""
add comment="watch and log Office3 router" down-script=\
    ":log error \"Office3 router unreachable\"" host=198.51.100.100 \
    interval=10s up-script=":log error \"Office3 router reachable\""
add comment="watch and log cloud service2" down-script=\
    ":log error \"cloud service2 unreachable\"" host=198.51.100.40 interval=10s \
    up-script=":log error \"cloud service2 reachable\""

