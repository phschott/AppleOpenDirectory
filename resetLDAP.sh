#!/bin/bash
sudo systemctl stop slapd
sudo rm -R /var/lib/ldap/
sudo dpkg-reconfigure slapd