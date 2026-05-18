# AppleOpenDirectory
This guide helps you to configure an OpenLDAP server compatible with Apple devices either on UTM or on Raspberry Pi

## Install debian
### Install UTM
Install UTM on your mac using Homebrew.
```shell
brew install utm
```

### Install Debian
Install Debian with no desktop to have better performance.
Download the small distribution for ARM64 or other depending on your os [here](https://www.debian.org/distrib/netinst)
Create a new VM:
- Select Vitualize
- Select Linux
- Select Apple virtualization for Linux and select iso image
- Modify VM to change network to Bridge Network en1 and add shared folder

Proceed to installation of Debian:
- Select "Install"
- Enter language options
- Enter machine name and domain
- Enter root password
- Enter additionnal username and password
- Create a single partition, select virtual disk N°1
- Install minimum packages: system and ssh server
- Eject CD and reboot

Install sudo if needed
```shell
apt update
apt upgrade
apt install sudo
```

### Add Share drive
```shell
sudo apt install spice-webdavd spice-vdagent qemu-guest-agent
mkdir /media/shared
sudo mount -t virtiofs share /media/shared/
sudo mount -t 9p -o trans=virtio share /media/shared/ -oversion=9p2000.L
```

### Configure ssh access to Debian
Create a new ssh key
```shell
ssh-keygen -t rsa -b 4096
```
Give a {name} to your new key
Load private key into remote
```shell
ssh-add --apple-use-keychain ~/.ssh/{name}
```

Transfer public key to host and add it to authorized_keys file
```shell
cd ~/.ssh/
cat {name}.pub >> authorized_keys
```

## Install & configure OpenLdap
### Install OpenLDAP
Install required package for openldap and start configuration.
```shell
apt install slapd ldap-utils
dpkg-reconfigure slapd
```

### Convert and add missing schemas
Copy the following file into /etc/ldap/schema/
- samba.schema
- apple_auxillary.schema
- apple.schema

They can be found on your mac under /etc/openldap/schema/

Create a schema_conv.conf file to convert schema file into ldif file.
schema_conv.conf file should contain
```
include /etc/ldap/schema/core.schema
include /etc/ldap/schema/cosine.schema
include /etc/ldap/schema/inetorgperson.schema
include /etc/ldap/schema/nis.schema
include /etc/ldap/schema/samba.schema
include /etc/ldap/schema/apple_auxillary.schema
include /etc/ldap/schema/apple.schema
```

Modify apple.schema file to:
 * Uncomment and move up some declaration authAuthority et container

Then execute the following command:
```shell
mkdir /tmp/ldif/
slaptest -f ./schema_conv.conf -F /tmp/ldif/
```

Open the /tmp/ldif/cn\=config/cn\=schema/cn\=\{5\}samba.ldif file and change the following lines:
```
dn: cn={5}samba
objectClass: olcSchemaConfig
cn: {5}samba
To:
```

to

```
dn: cn=samba,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: samba
Also delete these lines at the bottom:
```

Also delete these lines at the bottom:
```
structuralObjectClass: olcSchemaConfig
entryUUID: d53d1a8c-4261-1034-9085-738a9b3f3783
creatorsName: cn=config
createTimestamp: 20150206153742Z
entryCSN: 20150206153742.072733Z#000000#000#000000
modifiersName: cn=config
modifyTimestamp: 20150206153742Z
```

Copy generated ldif file (samba.ldif, apple.ldif and apple_auxillary.ldif) into /etc/ldap/schema/
```shell
cp /tmp/ldif/cn\=config/cn\=schema/cn\=\{4\}samba.ldif /etc/ldap/schema/samba.ldif
cp /tmp/ldif/cn\=config/cn\=schema/cn\=\{5\}apple_auxillary.ldif /etc/ldap/schema/apple_auxillary.ldif
cp /tmp/ldif/cn\=config/cn\=schema/cn\=\{6\}apple.ldif /etc/ldap/schema/apple.ldif
```

Load new schema into LDAP Server
```shell
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/samba.ldif
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/apple_auxillary.ldif
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/apple.ldif
```

Verify installed schemas
```shell
ldapsearch -LLLQY EXTERNAL -H ldapi:/// -b cn=schema,cn=config "(objectClass=olcSchemaConfig)" dn
```

### Configure sasl
Install sasl
```shell
apt install -y sasl2-bin
```

Configuration files
- Modify /etc/default/saslauthd
    - Add START=yes
    - Add MECHANISMS="ldap" instead of "pam"
- Create /etc/saslauthd.conf from sample in configFiles
- Create /etc/ldap/sasl2/slapd.conf from sample in configFiles

Restart saslauth
```shell
systemctl start saslauthd
systemctl enable saslauthd
```

Restart ldap and sasl
```shell
#!/bin/bash
sudo systemctl stop saslauthd
sudo systemctl start saslauthd
sudo systemctl stop slapd
sudo systemctl start slapd
```

### Create Directory stucture
Restore backup structure (empty) through Apache Directory studio
Create readonly only through Apache Directory Studio

Update access
```shell
ldapadd -x -D cn=admin,dc=ldap,dc=local -W -f /media/shared/ldap/ldifFiles/EmptyStructure.ldif
ldapadd -x -D cn=admin,dc=ldap,dc=local -W -f /media/shared/ldap/ldifFiles/readonly-user.ldif 
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /media/shared/ldap/ldifFiles/update-mdb-acl.ldif 
```

### Fix jpegPhoto modification error
To fix jpegPhoto modification and deletion error, create the following update-jpegPhoto.ldif file


0.9.2342.19200300.100.1.60 NAME 'jpegPhoto' DESC 'RFC2798: a JPEG image' SYNTAX 1.3.6.1.4.1.1466.115.121.1.28

```
dn: cn={3}inetorgperson,cn=schema,cn=config
changetype: modify
delete: olcAttributeTypes
olcAttributetypes: {5}( 0.9.2342.19200300.100.1.60 NAME 'jpegPhoto' DESC 'RFC2798: a JPEG image' SYNTAX 1.3.6.1.4.1.1466.115.121.1.28 )
-
add: olcAttributeTypes
olcAttributeTypes: {5}( 0.9.2342.19200300.100.1.60 NAME 'jpegPhoto' DESC 'RFC2798: a JPEG image' EQUALITY octetStringMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.28 )
```

And update Schema on server
```shell
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /media/shared/ldap/ldifFiles/update-jpegPhoto.ldif
```

## Configure Device
### Connect Mac to LDAP
Go in "Users and Groups" on your Mac OS device. Select "Add Network server" and enter IP of server.
Modify the LDAPv3 configuration of your server:
- Change to "Open Directory" and enter baseDN
- In Security tab enter readonly username and password.

### Create mobile account from command line
```shell
sudo /System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -n {username} -v -P
```

### Create profile to create mobile account
Use tool like [iMazing Profile Editor](https://imazing.com/profile-editor) to configure a profile.

In this profile add "Energy Saver, FileVault, Time Server, Mobile Accounts and Guest Account" and in "Mobile Accounts" tab check "Create Mobile Account at login time"

Install this profile on the Mac

## Connect through ldaps
Copy certificates into /etc/ssl/openldap/certs/
```shell
mkdir -p /etc/ssl/openldap/certs/
cp /media/shared/certs/* /etc/ssl/openldap/certs/
ldapmodify -Y EXTERNAL -H ldapi:/// -f /media/shared/ldifFiles/ldap-tls.ldif

ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config | grep olcTLS
```

Ensure that
    SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"
has been added to /etc/default/slapd 

Test connection from outside after changing DNS routing
```shell
ldapwhoami -x -ZZ -H ldap://ldap.local
ldapwhoami -x -H ldaps://ldap.local
```

## Useful links
- [Install OpenLDAP on RaspberryPi](https://raduzaharia.medium.com/building-an-identity-server-with-openldap-and-a-raspberry-pi-4-e19f829dd2eb)
- [Install OpenLDAP on Mac OS X](http://blog.facilelogin.com/2012/05/setting-up-openldap-under-mac-os-x.html)
- [Convert Schema to ldif](https://www.lisenet.com/2015/convert-openldap-schema-to-ldif/)
- [SASL Auth](https://docs.percona.com/percona-server-for-mongodb/4.4/sasl-auth.html)
- [OpenLDAP Authentication](targetURLhttps://kifarunix.com/configure-openldap-authentication-on-macos-x/)
- [Offline Authentication](targetURLhttps://kifarunix.com/configure-offline-authentication-via-openldap-on-macos-x/)
- [OpenLDAPSetup on Debian](https://wiki.debian.org/LDAP/OpenLDAPSetup)