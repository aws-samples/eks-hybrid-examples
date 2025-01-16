#!/bin/bash

# must be run as root

# create the script to block the ports
cat <<EOF > /usr/local/bin/iprules
#!/bin/bash

iptables -A OUTPUT -p tcp --dport 443 -j DROP; sudo iptables -A INPUT -p tcp  --dport 10250 -j DROP;
EOF

chmod +x /usr/local/bin/iprules

# create the systemd one-shot service unit file
cat <<EOF > /etc/systemd/system/iprules.service
[Unit]
Before=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/iprules

[Install]
WantedBy=multi-user.target
EOF

# enable the service
systemctl enable iprules.service

systemctl daemon-reload

# start the service
systemctl start iprules.service