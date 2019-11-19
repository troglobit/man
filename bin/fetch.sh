#!/bin/sh
# https://raw.githubusercontent.com/[USER-NAME]/[REPOSITORY-NAME]/[BRANCH-NAME]/[FILE-PATH]

fetch()
{
    subd=$1
    proj=$2
    path=$3
    file=$4

    mkdir -p $subd
    wget -nv -O $subd/$file https://raw.githubusercontent.com/troglobit/$proj/master/$path/$file &
}
repo()
{
    proj=$1
    path=$2
    shift 2

    echo "Fetching man pages from $proj ..."

    for file in $*; do
	subd=man"${file##*.}"
	fetch $subd $proj $path $file
    done
}

repo backlight . backlight.1
repo editline man editline.3
repo inadyn man inadyn.8 inadyn.conf.5
repo mcjoin . mcjoin.1
repo merecat man merecat.8 merecat.conf.5 redirect.8 ssi.8
repo mg . mg.1
repo mini-snmpd . mini_snmpd.8
repo mrouted man mrouted.8 mroutectl.8 mtrace.8 mrinfo.8 map-mbone.8 mrouted.conf.5
repo nemesis man nemesis.1 nemesis-dns.1 nemesis-igmp.1 nemesis-rip.1 nemesis-arp.1 \
     nemesis-ethernet.1 nemesis-ip.1 nemesis-tcp.1 nemesis-dhcp.1 nemesis-icmp.1 \
     nemesis-ospf.1 nemesis-udp.1
repo omping . omping.8
repo pim6sd man pim6sd.8 pim6sd.conf.5 pim6stat.1
repo pimd man pimd.8 pimctl.8
repo redir . redir.1
repo smcroute . smcroute.8
repo sysklogd man klogd.8 syslogd.8 syslogp.3 syslog.conf.5 logger.1
repo uftpd man uftpd.8
repo uredir . uredir.1
repo watchdogd man watchdogd.8 watchdogctl.1 watchdogd.conf.5
repo xplugd man xplugd.1

wait
