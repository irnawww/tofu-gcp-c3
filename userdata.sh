#!/bin/bash
apt-get update -y
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
echo "Hello, OpenTofu on GCP!" > /var/www/html/index.nginx-debian.html
