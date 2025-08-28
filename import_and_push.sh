#!/bin/bash

# --- 配置 ---
TAR_DIR="amd64_images"
NEW_REGISTRY="dockerhub.kubekey.local"

# --- 脚本安全设置 ---
set -e
set -o pipefail

# --- 颜色定义 ---
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'

# --- 检查依赖 ---
if ! command -v docker &> /dev/null
then
    echo -e "${COLOR_RED}错误: docker 命令未找到。请确保 Docker 已经安装并正在运行。${COLOR_NC}"
    exit 1
fi

# --- 检查目录是否存在 ---
if [ ! -d "$TAR_DIR" ]; then
    echo -e "${COLOR_RED}错误: 目录 '$TAR_DIR' 不存在。请确保 .tar 文件在该目录下。${COLOR_NC}"
    exit 1
fi

# --- 主逻辑 ---
echo -e "${COLOR_BLUE}开始处理目录 '$TAR_DIR' 中的镜像...${COLOR_NC}"

shopt -s nullglob
tar_files=("$TAR_DIR"/*.tar)

if [ ${#tar_files[@]} -eq 0 ]; then
    echo -e "${COLOR_RED}在 '$TAR_DIR' 目录中没有找到任何 .tar 文件。${COLOR_NC}"
    exit 1
fi

for tar_file in "${tar_files[@]}"; do
    echo -e "\n${COLOR_BLUE}--- 正在处理文件: $tar_file ---${COLOR_NC}"

    # 1. 导入镜像并捕获原始镜像名
    echo "1. 导入镜像..."
    original_image=$(docker load -i "$tar_file" | awk '/Loaded image:/ {print $3}')

    if [ -z "$original_image" ]; then
        echo -e "${COLOR_RED}从 '$tar_file' 加载镜像失败或未能识别镜像名称。${COLOR_NC}"
        continue
    fi
    echo -e "   ${COLOR_GREEN}成功加载: $original_image${COLOR_NC}"

    # --- vvvvvvvvvvvv 这是修正的核心逻辑 vvvvvvvvvvvv ---
    
    # 2. 智能地构建新的镜像路径
    image_path=""
    # 检查原始镜像名是否包含 '.' 在第一个 '/' 之前
    # 这可以区分 'registry.k8s.io/path/image' 和 'user/image' (Docker Hub)
    if [[ "$original_image" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/ ]]; then
        # 如果是 'registry.domain/path/image' 格式，则去掉域名部分
        image_path="${original_image#*\/}"
    else
        # 如果是 'user/image' 或 'image' 格式 (Docker Hub), 则保留完整路径
        # 补全可能缺失的 library/ 前缀 (针对官方镜像如 'ubuntu:22.04')
        if [[ "$original_image" != *"/"* ]]; then
            image_path="library/${original_image}"
            echo "   检测到官方 Docker Hub 镜像，补全路径为: $image_path"
        else
            image_path="$original_image"
        fi
    fi
    
    # 构建最终的新镜像名
    new_image="${NEW_REGISTRY}/${image_path}"

    # --- ^^^^^^^^^^^^ 修正的核心逻辑结束 ^^^^^^^^^^^^ ---


    # 3. 给镜像打上新标签
    echo "2. 重新打标签..."
    docker tag "$original_image" "$new_image"
    echo -e "   ${COLOR_GREEN}新标签: $new_image${COLOR_NC}"


    # 4. 推送新标签的镜像到私有仓库
    echo "3. 推送到 $NEW_REGISTRY..."
    docker push "$new_image"
    echo -e "   ${COLOR_GREEN}推送成功！${COLOR_NC}"


    # 5. (可选) 清理本地镜像以节省空间
    echo "4. 清理本地镜像..."
    docker rmi "$original_image" "$new_image"
    echo -e "   ${COLOR_GREEN}已清理。${COLOR_NC}"

done

echo -e "\n${COLOR_GREEN}所有镜像处理完毕！${COLOR_NC}"
