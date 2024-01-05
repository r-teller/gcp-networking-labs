interfaces {
    ethernet eth0 {
        address dhcp
    }
    ethernet eth1 {
        address dhcp
    }
    loopback lo {
    }
}

policy {
    as-path-list CORE-WAN-OUT {
        rule 10 {
            action permit
            regex ".*_4200000000_.*"
        }
    }
    route-map CORE-WAN-OUT {
        rule 10 {
            action deny
            match {
                as-path CORE-WAN-OUT
            }
        }
        rule 20 {
            action permit
        }
    }
    route-map DISTRO-LAN-OUT {
        rule 10 {
            action permit
        }
    }
}

protocols {
    bgp 4204100000 {
        timers {
            holdtime 60
            keepalive 20
        }
        neighbor 172.16.0.253 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    route-map {
                        export CORE-WAN-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4200000000
        }
        neighbor 172.16.0.252 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    route-map {
                        export CORE-WAN-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4200000000
        }
        neighbor 172.18.0.253 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    route-map {
                        export DISTRO-LAN-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4201000000
        }
        neighbor 172.18.0.252 {
            address-family {
                ipv4-unicast {
                    soft-reconfiguration {
                        inbound
                    }
                    route-map {
                        export DISTRO-LAN-OUT
                    }
                }
            }
            disable-connected-check
            ebgp-multihop 10
            remote-as 4201000000
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