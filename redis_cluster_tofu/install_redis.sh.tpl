#!/bin/bash
set -e
set -x

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y redis-server

sudo systemctl disable --now redis-server.service || true

# 注意：不再需要创建 redis 用户，因为 apt 安装时会自带

sudo sed -i "s/^port .*/port ${port}/" /etc/redis/redis.conf
sudo sed -i "s/^bind .*/bind 0.0.0.0/" /etc/redis/redis.conf
sudo sed -i 's/^protected-mode .*/protected-mode yes/' /etc/redis/redis.conf # 生产环境建议开启
sudo sed -i 's/^# cluster-enabled .*/cluster-enabled yes/' /etc/redis/redis.conf
sudo sed -i "s/^# cluster-config-file .*/cluster-config-file nodes-${port}.conf/" /etc/redis/redis.conf
sudo sed -i 's/^# cluster-node-timeout .*/cluster-node-timeout 15000/' /etc/redis/redis.conf
sudo sed -i "s/^# requirepass .*/requirepass ${redis_password}/" /etc/redis/redis.conf
sudo sed -i "s/^# masterauth .*/masterauth ${redis_password}/" /etc/redis/redis.conf

sudo chown redis:redis /var/lib/redis
sudo chown redis:redis /etc/redis/redis.conf

sudo systemctl restart redis-server
sleep 5
sudo systemctl status redis-server --no-pager
