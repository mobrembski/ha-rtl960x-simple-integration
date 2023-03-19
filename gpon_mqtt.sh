#!/bin/bash
SSH_PASS='admin'
GPON_TERMINAL_ADDR=modem.stal
MQTT_SERVER=homeassistant.stal
MQTT_PORT=1883
MQTT_USER=mqtt
MQTT_PASS=666mqtt
MQTT_TOPIC=modem/mainData
SSH_OPTIONS='-o ConnectTimeout=3 -o StrictHostKeyChecking=no -o PubkeyAcceptedAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o KexAlgorithms=+diffie-hellman-group1-sha1 -o HostKeyAlgorithms=+ssh-rsa -o Ciphers=+3des-cbc'

BINDED=$(timeout 10s sshpass -p $SSH_PASS ssh $SSH_OPTIONS admin@$GPON_TERMINAL_ADDR -C 'mount | grep wlfon')
if [ -z "$BINDED" ]; then
  echo "Not installed..."
  sshpass -p 'admin' ssh $SSH_OPTIONS admin@$GPON_TERMINAL_ADDR -C 'mount -o bind /var/config/status.json /home/httpd/web/wlfon.asp'
fi
echo "Installed...Continue"
curl -s -d "challenge=&username=admin&password=$SSH_PASS&save=Login&submit-url=%2Fadmin%2Flogin.asp" -X POST http://192.168.100.1/boaform/admin/formLogin > /dev/null
echo "Done login"
CONTENT=$(curl -s http://192.168.100.1/wlfon.asp)
ONUState=$(timeout 10s sshpass -p $SSH_PASS ssh $SSH_OPTIONS admin@$GPON_TERMINAL_ADDR -C 'diag gpon get onu-state | grep ONU')
MEMINFO=$(timeout 10s sshpass -p $SSH_PASS ssh $SSH_OPTIONS admin@$GPON_TERMINAL_ADDR -C 'cat /proc/meminfo' | awk '/MemTotal/ {total=$2} /MemFree/ {free=$2} /Buffers/ {buffers=$2} $1 ~ /^Cache/ {cached=$2} END {printf "%1d %.1f", ((total - free) - (buffers + cached)), (((total - free) - (buffers + cached))/total)*100}')
UPTIME_RAW=$(timeout 10s sshpass -p $SSH_PASS ssh $SSH_OPTIONS admin@$GPON_TERMINAL_ADDR -C 'cat /proc/uptime')

mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "$MQTT_TOPIC" -m "$CONTENT"
mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "modem/ONUState" -m "$(echo $ONUState | awk '{print $3" "$4 $5 $6}')"
mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "modem/FreeMem" -m "$(echo $MEMINFO | awk '{print $1}')"
mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "modem/FreeMemPercentage" -m "$(echo $MEMINFO | awk '{print $2}')"
mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "modem/UptimeRaw" -m "$(echo $UPTIME_RAW | awk '{print $1}')"
mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "modem/UptimeIdleRaw" -m "$(echo $UPTIME_RAW | awk '{print $2}')"
mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT -u $MQTT_USER -P $MQTT_PASS -t "modem/timestamp" -m "$(date)"

