#!/bin/bash
#Fixes a bug, where stopping the container once makes it crash on restart
rm /var/run/starter.charon.pid

sysctl -w net.ipv4.conf.all.rp_filter=2
#Forward packets
sysctl -w net.ipv4.ip_forward=1

iptables --table nat --append POSTROUTING --jump MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
for each in /proc/sys/net/ipv4/conf/*
do
	echo 0 > $each/accept_redirects
	echo 0 > $each/send_redirects
done

if [ "$VPN_PSK" = "password" ] || [ "$VPN_PSK" = "" ]; then
	# Generate a random password
	P1=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
	P2=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
	P3=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
	VPN_PSK="$P1$P2$P3"
	echo "No VPN_PSK set! Generated a random PSK key: $VPN_PSK"
fi

if [ ! -f "/etc/ipsec.secrets" ]; then
        echo "/etc/ipsec.secrets does not exists. Generating it."

cat > /etc/ipsec.secrets <<EOF
# This file holds shared secrets or RSA private keys for authentication.
# RSA private key for this host, authenticating it to any other host
# which knows the public part.  Suitable public keys, for ipsec.conf, DNS,
# or configuration of other implementations, can be extracted conveniently
# with "ipsec showhostkey".

: PSK "$VPN_PSK"

$VPN_USER : EAP "$VPN_PASSWORD"
$VPN_USER : XAUTH "$VPN_PASSWORD"
EOF
fi
echo "Generating /etc/strongswan.conf"
cat > /etc/strongswan.conf << EOF
# /etc/strongswan.conf - strongSwan configuration file
# strongswan.conf - strongSwan configuration file
#
# Refer to the strongswan.conf(5) manpage for details

charon {
        load_modular = yes
        send_vendor_id = yes
        i_dont_care_about_security_and_use_aggressive_mode_psk=yes
        plugins {
                include strongswan.d/charon/*.conf
                attr {
                        dns = 8.8.8.8, 8.8.4.4
                }
        }
}

include strongswan.d/*.conf

EOF
echo "Generating /etc/ipsec.conf"
cat > /etc/ipsec.conf <<EOF
config setup
conn %default
 leftsubnet=$SERVER_SUBNET
 authby=secret
 auto=add

conn fb
 left=%any
 leftid=%any
 ike=aes256-sha-modp1024
 esp=aes256-sha1-modp1024
 right=%any
 rightsubnet=$FRITZBOX_SUBNET
 ikelifetime=3600s
 keylife=3600s
 dpdaction=restart
 dpdtimeout=60
 dpddelay=30
 reauth=yes
 rekey=yes
 margintime=9m
 aggressive=yes

EOF

if [ -f "/etc/ipsec.d/l2tp-secrets" ]; then
	echo "Overwriting standard /etc/ppp/l2tp-secrets with /etc/ipsec.d/l2tp-secrets"
	cp -f /etc/ipsec.d/l2tp-secrets /etc/ppp/l2tp-secrets
fi

if [ -f "/etc/ipsec.d/ipsec.secrets" ]; then
	echo "Overwriting standard /etc/ipsec.secrets with /etc/ipsec.d/ipsec.secrets"
	cp -f /etc/ipsec.d/ipsec.secrets /etc/ipsec.secrets
fi

if [ -f "/etc/ipsec.d/ipsec.conf" ]; then
	echo "Overwriting standard /etc/ipsec.conf with /etc/ipsec.d/ipsec.conf"
	cp -f /etc/ipsec.d/ipsec.conf /etc/ipsec.conf
fi

if [ -f "/etc/ipsec.d/strongswan.conf" ]; then
	echo "Overwriting standard /etc/strongswan.conf with /etc/ipsec.d/strongswan.conf"
	cp -f /etc/ipsec.d/strongswan.conf /etc/strongswan.conf
fi

if [ -f "/etc/ipsec.d/xl2tpd.conf" ]; then
	echo "Overwriting standard /etc/xl2tpd/xl2tpd.conf with /etc/ipsec.d/xl2tpd.conf"
	cp -f /etc/ipsec.d/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
fi

echo "Starting StrongSwan process..."
#mkdir -p /var/run/xl2tpd
#/usr/sbin/xl2tpd -c /etc/xl2tpd/xl2tpd.conf

ipsec start --nofork
#Add this line to not stop the container instantly on errors.
#while true; do sleep 1000; done

