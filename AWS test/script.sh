#!/bin/bash

IP_ADDRESS="10.0.2.20"
PORT="55000"

function check_port() {
    nc -zv "$IP_ADDRESS" "$PORT" >/dev/null 2>&1
    return $?
}

while ! check_port; do
    echo "Pinging $IP_ADDRESS on port $PORT..." >> /var/log/logfile.txt
    sleep 1
done

echo "The ping to $IP_ADDRESS on port $PORt!" >> /var/log/logfile.txt

curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.4.3-1_amd64.deb && sudo WAZUH_MANAGER='10.0.2.20' WAZUH_AGENT_GROUP='default' WAZUH_AGENT_NAME='Test' dpkg -i ./wazuh-agent.deb
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent

echo "The installation was successful!" >> /var/log/logfile.txt