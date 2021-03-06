ACMBSD automation script for ACMCMS on FreeBSD OS

1.0 Install FreeBSD

First you need to install FreeBSD: https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/bsdinstall.html

Do next sections after you get terminal access

1.1 Install acmbsd

1.1.1 Switch **pkg** to **latest** repo
```
mkdir -p /usr/local/etc/pkg/repos
echo 'FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }' > /usr/local/etc/pkg/repos/FreeBSD.conf
```

1.1.2 Install root certificate bundle
```
pkg install -y ca_root_nss
```

1.1.3 Fetch and run installation script
```
fetch https://raw.githubusercontent.com/acmcms/acm-install-freebsd/master/sh-scripts/install-freebsd.sh -o - | sh -e
```

1.2 Add new group of instances
```
acmbsd add live
acmbsd update live -agree
```

1.3 Configure system and group

To see config command syntax and available group list execute this command:
`acmbsd config`

Change manager email address:
`acmbsd config system -email=user@example.net`

Check other system settings:
`acmbsd config system`

Change available memory:
`acmbsd config live -memory=640m`

Check other group settings:
`acmbsd config live`

1.4 Start group of instances
`acmbsd start live`

1.5 Adding new host to cluster
```
acmbsd cluster activate
acmbsd cluster addto -host=user@cluster.example.org
acmbsd cluster cron -enable=true
```
* Note: 'cluster.example.org' it's host that already in cluster
