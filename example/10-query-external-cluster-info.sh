#!/bin/bash

# ==============================================================================
# 生成 Rook-Ceph 外部集群连接配置 (最终版)
#
# 作者: AI Assistant
# 版本: FINAL-OUTPUT
#
# 此脚本查询所有必需的物理 IP 和 NodePort，并直接生成可用的 export 命令。
# ==============================================================================

set -e
set -o pipefail

# --- 配置 ---
ROOK_NAMESPACE="rook-ceph"

# --- 颜色定义 ---
C_RESET='\033[0m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'

# --- 主逻辑 ---
echo -e "${C_YELLOW}======================================================================${C_RESET}"
echo -e "${C_YELLOW}         正在查询并生成消费者集群所需的 export 配置...         ${C_RESET}"
echo -e "${C_YELLOW}======================================================================${C_RESET}\n"

# --- 1. 获取所有 NodePort ---
DASHBOARD_PORT=$(kubectl -n "$ROOK_NAMESPACE" get svc rook-ceph-mgr-dashboard-external -o jsonpath='{.spec.ports[0].nodePort}')
MGR_PORT=$(kubectl -n "$ROOK_NAMESPACE" get svc rook-ceph-mgr-external -o jsonpath='{.spec.ports[0].nodePort}')
MON_A_PORT=$(kubectl -n "$ROOK_NAMESPACE" get svc rook-ceph-mon-a-external -o jsonpath='{.spec.ports[?(@.name=="msgr1")].nodePort}')
MON_B_PORT=$(kubectl -n "$ROOK_NAMESPACE" get svc rook-ceph-mon-b-external -o jsonpath='{.spec.ports[?(@.name=="msgr1")].nodePort}')
MON_C_PORT=$(kubectl -n "$ROOK_NAMESPACE" get svc rook-ceph-mon-c-external -o jsonpath='{.spec.ports[?(@.name=="msgr1")].nodePort}')

# --- 2. 获取所有节点的物理 IP ---
MON_A_IP=$(kubectl -n "$ROOK_NAMESPACE" get pod -l mon=a -o jsonpath='{.items[0].status.hostIP}')
MON_B_IP=$(kubectl -n "$ROOK_NAMESPACE" get pod -l mon=b -o jsonpath='{.items[0].status.hostIP}')
MON_C_IP=$(kubectl -n "$ROOK_NAMESPACE" get pod -l mon=c -o jsonpath='{.items[0].status.hostIP}')
MGR_IPS=$(kubectl -n "$ROOK_NAMESPACE" get pod -l app=rook-ceph-mgr -o jsonpath='{.items[*].status.hostIP}' | tr ' ' ',')
# 随便选一个 IP 作为通用访问 IP
GENERAL_IP=$MON_A_IP

# --- 3. 拼接最终的字符串 ---
FINAL_MON_DATA="${MON_A_IP}:${MON_A_PORT},${MON_B_IP}:${MON_B_PORT},${MON_C_IP}:${MON_C_PORT}"
FINAL_DASHBOARD_LINK="https://""${GENERAL_IP}:${DASHBOARD_PORT}/"
FINAL_MONITORING_ENDPOINT="${MGR_IPS}"
FINAL_MONITORING_PORT="${MGR_PORT}"


# --- 4. 打印最终结果 ---
echo "请用下面的内容，完整替换掉 '09-import-external-cluster.sh' 文件中对应的行："
echo -e "${C_YELLOW}----------------------------------------------------------------------${C_RESET}"

echo -e "export ROOK_EXTERNAL_CEPH_MON_DATA=\"${C_CYAN}${FINAL_MON_DATA}${C_RESET}\""
echo -e "export ROOK_EXTERNAL_DASHBOARD_LINK=\"${C_CYAN}${FINAL_DASHBOARD_LINK}${C_RESET}\""
echo -e "export MONITORING_ENDPOINT=\"${C_CYAN}${FINAL_MONITORING_ENDPOINT}${C_RESET}\""
echo -e "export MONITORING_ENDPOINT_PORT=\"${C_CYAN}${FINAL_MONITORING_PORT}${C_RESET}\""

echo -e "${C_YELLOW}----------------------------------------------------------------------${C_RESET}"
