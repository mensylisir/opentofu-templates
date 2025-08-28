#!/bin/bash

set -e
set -o pipefail

ROOK_NAMESPACE="rook-ceph"
TOOLS_DEPLOYMENT="rook-ceph-tools"

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'

echo -e "${C_YELLOW}======================================================================${C_RESET}"
echo -e "${C_YELLOW}         Rook-Ceph 外部集群连接信息查询脚本         ${C_RESET}"
echo -e "${C_YELLOW}======================================================================${C_RESET}\n"

echo -e "${C_CYAN}--> 正在查找 rook-ceph-tools Pod...${C_RESET}"
TOOLS_POD_NAME=$(kubectl -n "$ROOK_NAMESPACE" get pod -l "app=$TOOLS_DEPLOYMENT" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$TOOLS_POD_NAME" ]; then
    echo -e "\033[0;31m错误: 找不到 rook-ceph-tools pod。\033[0m" >&2
    exit 1
fi
echo -e "${C_GREEN}找到 Tools Pod: ${TOOLS_POD_NAME}${C_RESET}\n"

echo -e "${C_CYAN}--> 正在从 Ceph 集群提取信息...${C_RESET}"

FSID=$(kubectl -n "$ROOK_NAMESPACE" exec -i "$TOOLS_POD_NAME" -- ceph fsid)

MON_POD_INFO=$(kubectl -n "$ROOK_NAMESPACE" get pods -l app=rook-ceph-mon -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq)
MON_HOST_IP_MAP=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')

MON_ENDPOINTS=""
while read -r name; do
    host_ip=$(echo "$MON_HOST_IP_MAP" | grep "^$name " | awk '{print $2}')
    if [ -n "$MON_ENDPOINTS" ]; then
        MON_ENDPOINTS="${MON_ENDPOINTS},"
    fi
    MON_ENDPOINTS="${MON_ENDPOINTS}${host_ip}:6789"
done <<< "$MON_POD_INFO"

CSI_RBD_NODE_SECRET=$(kubectl -n "$ROOK_NAMESPACE" exec -i "$TOOLS_POD_NAME" -- bash -c "ceph auth get-or-create client.csi-rbd-node mon 'profile rbd' osd 'profile rbd' mgr 'profile rbd'")
CSI_RBD_PROVISIONER_SECRET=$(kubectl -n "$ROOK_NAMESPACE" exec -i "$TOOLS_POD_NAME" -- bash -c "ceph auth get-or-create client.csi-rbd-provisioner mon 'profile rbd' osd 'profile rbd' mgr 'profile rbd'")
CSI_CEPHFS_NODE_SECRET=$(kubectl -n "$ROOK_NAMESPACE" exec -i "$TOOLS_POD_NAME" -- bash -c "ceph auth get-or-create client.csi-cephfs-node mon 'allow r' osd 'allow rw' mds 'allow rwm' mgr 'allow r'")
CSI_CEPHFS_PROVISIONER_SECRET=$(kubectl -n "$ROOK_NAMESPACE" exec -i "$TOOLS_POD_NAME" -- bash -c "ceph auth get-or-create client.csi-cephfs-provisioner mon 'allow r' mgr 'allow rw'")
echo -e "${C_GREEN}所有信息提取完毕。${C_RESET}\n"


echo -e "${C_YELLOW}======================================================================${C_RESET}"
echo -e "${C_YELLOW}         请将以下信息复制并填写到消费者集群的配置文件中         ${C_RESET}"
echo -e "${C_YELLOW}======================================================================${C_RESET}\n"

echo -e "${C_GREEN}1. 集群 FSID:${C_RESET}"
echo "${FSID}"
echo ""

echo -e "${C_GREEN}2. Monitor Endpoints (物理IP地址):${C_RESET}"
echo "${MON_ENDPOINTS}"
echo ""

echo -e "${C_GREEN}3. CSI RBD Node Secret Key:${C_RESET}"
echo "${CSI_RBD_NODE_SECRET}"
echo ""

echo -e "${C_GREEN}4. CSI RBD Provisioner Secret Key:${C_RESET}"
echo "${CSI_RBD_PROVISIONER_SECRET}"
echo ""

echo -e "${C_GREEN}5. CSI CephFS Node Secret Key:${C_RESET}"
echo "${CSI_CEPHFS_NODE_SECRET}"
echo ""

echo -e "${C_GREEN}6. CSI CephFS Provisioner Secret Key:${C_RESET}"
echo "${CSI_CEPHFS_PROVISIONER_SECRET}"
echo ""

echo -e "${C_YELLOW}======================================================================${C_RESET}"
