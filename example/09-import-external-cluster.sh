export ARGS="[Configurations]
namespace = rook-ceph
rgw-pool-prefix = default
format = bash
cephfs-filesystem-name = myfs
cephfs-metadata-pool-name = myfs-metadata
cephfs-data-pool-name = myfs-data0
rbd-data-pool-name = replicapool
rgw-endpoint = rook-ceph-rgw-my-store.rook-ceph.svc:80
"
export CEPHX_KEY_GENERATION=1
export NAMESPACE=rook-ceph
export ROOK_EXTERNAL_FSID=57ad78fb-4a4f-4068-a178-593b9c7e7af4
export ROOK_EXTERNAL_USERNAME=client.healthchecker
export ROOK_EXTERNAL_CEPH_MON_DATA=192.168.150.155:31806,192.168.150.129:30265,192.168.150.128:30909
export ROOK_EXTERNAL_USER_SECRET=AQCZWahoY5POGxAAIS2k3lwMuICA5yMCJ9BDug==
export ROOK_EXTERNAL_DASHBOARD_LINK=https://192.168.150.155:32113/
export CSI_RBD_NODE_SECRET=AQAYBKhomn+lMxAAKedctdfOi9dFa6PtrPMAew==
export CSI_RBD_NODE_SECRET_NAME=csi-rbd-node
export CSI_RBD_PROVISIONER_SECRET=AQAYBKhoy1pnFRAAD24hdc8+D9NrdxC5yuMITw==
export CSI_RBD_PROVISIONER_SECRET_NAME=csi-rbd-provisioner
export CEPHFS_POOL_NAME=myfs-data0
export CEPHFS_METADATA_POOL_NAME=myfs-metadata
export CEPHFS_FS_NAME=myfs
export CSI_CEPHFS_NODE_SECRET=AQAaBKhoZ+4vBRAAIQWtH5Fn6CMtn9z8StSfig==
export CSI_CEPHFS_PROVISIONER_SECRET=AQAZBKho853NHBAA8uPf5Ls48qc74jK3DEBvFw==
export CSI_CEPHFS_NODE_SECRET_NAME=csi-cephfs-node
export CSI_CEPHFS_PROVISIONER_SECRET_NAME=csi-cephfs-provisioner
export MONITORING_ENDPOINT=192.168.150.129,192.168.150.128
export MONITORING_ENDPOINT_PORT=30187
export RBD_POOL_NAME=replicapool
export RGW_POOL_PREFIX=default
export RGW_ADMIN_OPS_USER_ACCESS_KEY=W7GO9BREK49SZO9ARKSR
export RGW_ADMIN_OPS_USER_SECRET_KEY=4TDESF8r6BTCxooptSxqPZk5n1eoPyzSBzd0Xu4T

