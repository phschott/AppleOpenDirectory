#!/bin/bash
sudo systemctl stop saslauthd
sudo systemctl start saslauthd
sudo systemctl stop slapd
sudo systemctl start slapd