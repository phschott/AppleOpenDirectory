#!/bin/bash
#openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout ldap.local.key -out ldap.local.crt -subj "/CN=ldap.local" -addext "subjectAltName=DNS:ldap.local,IP:10.0.0.1"
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout ./certs/ldap.local.key -out ./certs/ldap.local.crt -subj "/CN=ldap" -addext "subjectAltName=DNS:ldap"