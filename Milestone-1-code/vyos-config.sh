#!/bin/vbash
set interfaces ethernet eth0 address '192.168.3.14/24'
set interfaces ethernet eth0 description 'CYBERLAB'
set interfaces ethernet eth0 hw-id '00:0c:29:21:73:cd'
set interfaces ethernet eth1 address '10.0.17.2/24'
set interfaces ethernet eth1 description '480-WAN'
set interfaces ethernet eth1 hw-id '00:0c:29:21:73:d7'
set interfaces loopback lo
set nat source rule 10 outbound-interface 'eth0'
set nat source rule 10 source address '10.0.17.0/24'
set nat source rule 10 translation address 'masquerade'
set protocols static route 0.0.0.0/0 next-hop 192.168.3.250
set service dns forwarding allow-from '10.0.17.0/24'
set service dns forwarding listen-address '10.0.17.2'
set service dns forwarding system
set service ssh listen-address '0.0.0.0'
set system config-management commit-revisions '100'
set system conntrack modules ftp
set system conntrack modules h323
set system conntrack modules nfs
set system conntrack modules pptp
set system conntrack modules sip
set system conntrack modules sqlnet
set system conntrack modules tftp
set system console device ttyS0 speed '115200'
set system host-name 'benjamin-480-firewall'
set system name-server '192.168.4.4'
set system name-server '192.168.4.5'
set system ntp server time1.vyos.net
set system ntp server time2.vyos.net
set system ntp server time3.vyos.net
set system syslog global facility all level 'info'
set system syslog global facility protocols level 'debug'
#!- End of configuration