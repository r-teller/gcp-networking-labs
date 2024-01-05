interfaces {
    ethernet eth0 {
        address dhcp
    }
    ethernet eth1 {
        address dhcp
    }
    ethernet eth2 {
        address dhcp
    }
    ethernet eth3 {
        address dhcp
    }
    loopback lo {
    }
}

policy {
    prefix-list DISTRO-LAN-OUT {
        rule 10 {
            action deny
            prefix 0.0.0.0/0
        }
        rule 11 {
            action deny
            prefix 0.0.0.0/1
        }
        rule 12 {
            action deny
            prefix 128.0.0.0/1
        }
        rule 20 {
            action permit
            prefix 10.0.0.0/8
            ge 9
        }
        rule 21 {
            action permit
            prefix 172.16.0.0/12
            ge 13
        }
        rule 22 {
            action permit
            prefix 192.168.0.0/16
            ge 17
        }
    }
    as-path-list DISTRO-LAN-OUT {
        rule 10 {
            action permit
            regex '^[0-9]+_[0-9]+_[0-9]+_'
    }   
    }    
    route-map DISTRO-LAN-OUT {
        rule 10 {
            action deny
            match {
                as-path DISTRO-LAN-OUT
            }
        }
        rule 20 {
            action permit
        }
    }
    prefix-list ACCESS-TRUSTED-AA00-OUT {
        rule 10 {
            action permit
            prefix 0.0.0.0/1
        }
        rule 11 {
            action permit
            prefix 128.0.0.0/1
        }
    }
    route-map ACCESS-TRUSTED-AA00-OUT {
        rule 10 {
            action permit
            match {
                ip {
                    address {
                        prefix-list ACCESS-TRUSTED-AA00-OUT 
                    }
                }
            }
        }
    }
    prefix-list ACCESS-TRUSTED-AB00-OUT {
        rule 10 {
            action permit
            prefix 0.0.0.0/1
        }
        rule 11 {
            action permit
            prefix 128.0.0.0/1
        }
    }
    route-map ACCESS-TRUSTED-AB00-OUT {
        rule 10 {
            action permit
            match {
                ip {
                    address {
                        prefix-list ACCESS-TRUSTED-AB00-OUT 
                    }
                }
            }
        }
    }
    prefix-list ACCESS-TRUSTED-TRANSIT-OUT {
        rule 10 {
            action permit
            prefix 0.0.0.0/0
        }
    }
    route-map ACCESS-TRUSTED-TRANSIT-OUT {
        rule 10 {
            action permit
            match {
                ip {
                    address {
                        prefix-list ACCESS-TRUSTED-TRANSIT-OUT 
                    }
                }
            }
        }
    }
}

protocols {
    bgp 4214100001 {
        timers {
            holdtime 60
            keepalive 20
        }
        address-family {
            ipv4-unicast {
                network 0.0.0.0/0 { }
                network 0.0.0.0/1 { }
                network 128.0.0.0/1 { }
            }
        }
        neighbor 172.18.1.253 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export DISTRO-LAN-OUT
                    }
                    route-map {
                        export DISTRO-LAN-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4211000000
        }
        neighbor 172.18.1.252 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export DISTRO-LAN-OUT
                    }
                    route-map {
                        export DISTRO-LAN-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4211000000
        }
        neighbor 172.24.65.253 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export ACCESS-TRUSTED-TRANSIT-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4212000001
        }
        neighbor 172.24.65.252 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export ACCESS-TRUSTED-TRANSIT-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4212000001
        }
        neighbor 172.24.1.253 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export ACCESS-TRUSTED-AA00-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4212000002
        }
        neighbor 172.24.1.252 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export ACCESS-TRUSTED-AA00-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4212000002
        }
        neighbor 172.24.33.253 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export ACCESS-TRUSTED-AB00-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4212000003
        }
        neighbor 172.24.33.252 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    prefix-list {
                        export ACCESS-TRUSTED-AB00-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4212000003
        }
    }
}

service {
    ssh {
        listen-address 0.0.0.0
        port 22
        disable-password-authentication
    }
}

system {
    config-management {
        commit-revisions 100
    }
    conntrack {
        modules {
            ftp
            h323
            nfs
            pptp
            sip
            sqlnet
            tftp
        }
    }
    console {
        device ttyS0 {
            speed 38400
        }
    }
    host-name vyos-gce
    login {
        banner {
            post-login "Welcome to VyOs\n=========================================================================\nPlease note the following:\n    * This image is integrated with Google Ops Agent and supports metadata\nssh-keys login;\n    * You can still manage vyos configuration using the Serial Console,\nlogging in as vyos credentials: vyos/vyos;\n    * Note: vyos ssh plaintext/password is disabled.\n\nBuilt using https://github.com/albertogeniola/terraform-gce-vyos\n========================================================================="
        }
        user vyos {
            authentication {
                encrypted-password $6$gf2ShN8QhLqyH$WedSwHWXMYgC/qoM7ibe2XwdZro.A.qsYqMH0P9jf5opselu31ACTUD1bkRTL8S3WeKjoJ1Uu2xOgZXSV9SOr1
                plaintext-password ""
            }
        }
        user admin {
        }
    }
    name-server 169.254.169.254    
    ntp {
        server time1.vyos.net {
        }
        server time2.vyos.net {
        }
        server time3.vyos.net {
        }
    }
    static-host-mapping {
        host-name metadata.google.internal {
            inet 169.254.169.254
        }
    }
    syslog {
        global {
            facility all {
                level info
            }
            facility protocols {
                level debug
            }
        }
    }
}
// Warning: Do not remove the following line.
// vyos-config-version: "broadcast-relay@1:cluster@1:config-management@1:conntrack@3:conntrack-sync@2:dhcp-relay@2:dhcp-server@6:dhcpv6-server@1:dns-forwarding@3:firewall@5:https@2:interfaces@22:ipoe-server@1:ipsec@5:isis@1:l2tp@3:lldp@1:mdns@1:nat@5:ntp@1:pppoe-server@5:pptp@2:qos@1:quagga@8:rpki@1:salt@1:snmp@2:ssh@2:sstp@3:system@21:vrrp@2:vyos-accel-ppp@2:wanloadbalance@3:webproxy@2:zone-policy@1"
// Release version: equuleus