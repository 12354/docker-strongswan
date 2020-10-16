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

echo "Generating /etc/ipsec.conf"
cat > /etc/ipsec.conf <<EOF

config setup
conn %default
 left=%defaultroute
 leftsubnet=$SERVER_SUBNET
 authby=secret
 auto=start

conn fb
 ike=aes256-sha-modp1024
 esp=aes256-sha1-modp1024
 right=%any
 rightid=%any
 rightsubnet=$FRITZBOX_SUBNET
 ikelifetime=3600s
 keylife=3600s
EOF
cat << EOF
Import the following vpn configuration file to your fritzbox after changing the marked values:
vpncfg {
  connections {
    enabled = yes;
    editable = no;
    conn_type = conntype_lan;
    name = "FritzBox Strongswan VPN";
    boxuser_id = 0;
    always_renew = yes;
    reject_not_encrypted = no;
    dont_filter_netbios = yes;
    localip = 0.0.0.0;
    local_virtualip = 0.0.0.0;
    remoteip = 0.0.0.0;
    remote_virtualip = 0.0.0.0;
    remotehostname = "vpn.domain.org"; //Change this to the domain/ip of your server
    keepalive_ip = 0.0.0.0;
    mode = phase1_mode_idp;
    phase1ss = "all/all/all";
    keytype = connkeytype_pre_shared;
    key = "SecretKey!"; //Change this to your preshared secret key(PSK)
    cert_do_server_auth = no;
    use_nat_t = yes;
    use_xauth = no;
    use_cfgmode = no;
    phase2localid {
      ipnet {
        ipaddr = 192.168.10.0;  //Change these line to the subnet
        mask = 255.255.255.0;   //of your fritzbox
      }
    }
    phase2remoteid {
      ipnet {
        ipaddr = 172.19.0.0;  //Change these lines to the subnet
        mask = 255.255.255.0; //of your server
      }
    }
    phase2ss = "esp-all-all/ah-none/comp-all/pfs";
    accesslist = "permit ip any 172.19.0.0 255.255.255.0"; 
		//This configures which ips are routed over the vpn connection
		//I changed it so only local ips from the server subnet are routed through the vpn
  }
  ike_forward_rules = "udp 0.0.0.0:500 0.0.0.0:500", 
  "udp 0.0.0.0:4500 0.0.0.0:4500";
}
}

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

echo "Starting XL2TPD process..."
mkdir -p /var/run/xl2tpd
/usr/sbin/xl2tpd -c /etc/xl2tpd/xl2tpd.conf

ipsec start --nofork\

while true; do sleep 1000; done

