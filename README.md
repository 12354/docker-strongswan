# Connect your Fritzbox Lan2Lan to your Server with Strongswan VPN on Docker

This docker image allows you to connect your fritzbox lan directly to your servers lan using an ipsec vpn connection powered by StrongSwan.


Tested using a FritzBox 7430
## Usage
Run the following to start the container:

```
docker run -d -p 500:500/udp -p 4500:4500/udp --privileged --env FRITZBOX_SUBNET=192.168.10.0/24 --env SERVER_SUBNET=172.19.0.0/24 --env VPN_PSK=SecretKey! the12354/fritzbox-strongswan-vpn-server
```
Notice the following environment variables:
```
FRITZBOX_SUBNET=192.168.10.0/24 
SERVER_SUBNET=172.19.0.0/24 
VPN_PSK=SecretKey!
```
Change these to your subnets and your preshared key!
If you haven't set a preshared secret key(PSK) via the environment variables, then a new random psk will be set. To get it, read the logs of the running container:



```
docker logs <CONTAINER>
```
Search for this line in the output at the top:
```
No VPN_PSK set! Generated a random PSK key: NZESSabnC
```
## FritzBox configuration
To add the vpn connection to your fritzbox, configure a new lan-lan vpn connection(""Connect your home network with another FRITZ!Box network (LAN-LAN linkup)") to this server.
It should work without any additional configuration.


This uses the **unsafe** aggressive mode.

By setting the environment variable *USE_SAFE_VPN* to true, a safe vpn config without aggressive mode will be generated and a vpn config file for your fritz box will be displayed in the logs.


```
docker logs <CONTAINER>
```
Copy this to a vpn.txt file, change the remaining unfilled values to your personal values and import this file to your fritzbox.


Here is my configuration, which you can follow to edit yours:
```
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
```



## Logs

To read the logs use the default docker logs command:
```
docker logs <CONTAINER>
```


## Services running

There is one service running: *Strongswan*

The default IPSec configuration supports:

* IKEv1 with PSK

The ports that are exposed for this container to work are:

* 4500/udp and 500/udp for IPSec 
