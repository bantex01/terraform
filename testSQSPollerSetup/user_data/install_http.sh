#!/bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo service httpd start
sudo chkconfig httpd on

host=`hostname`
echo "<h1>hello from ${host}</h1>" > /var/www/html/index.html
