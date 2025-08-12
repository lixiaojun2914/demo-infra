#!/bin/bash

# 设置错误时退出
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 系统更新和安装
system_update() {
    log_info "开始系统更新..."
    
    # 更新包列表
    log_info "更新包列表..."
    apt update -y
    
    # 升级系统包
    log_info "升级系统包..."
    apt upgrade -y
    
    # 安装必要的软件包（不安装系统级ansible，在虚拟环境中安装特定版本）
    log_info "安装 Python 3.12、Git、containerd 和 iptables-persistent..."
    apt install python3.12 python3.12-venv python3-pip git containerd iptables-persistent -y
    
    log_success "系统更新和安装完成"
}



# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBESPRAY_DIR="$(dirname "$PROJECT_ROOT")/kubespray"
CONFIG_SOURCE_DIR="$PROJECT_ROOT/kubespray/mycluster"

# 设置虚拟环境变量
VENVDIR="$(dirname "$PROJECT_ROOT")/kubespray-venv"
KUBESPRAYDIR="kubespray"

log_info "脚本目录: $SCRIPT_DIR"
log_info "项目根目录: $PROJECT_ROOT"
log_info "kubespray 目标目录: $KUBESPRAY_DIR"
log_info "配置文件源目录: $CONFIG_SOURCE_DIR"
log_info "虚拟环境目录: $VENVDIR"

# 克隆kubespray项目
clone_kubespray() {
    log_info "克隆 kubespray 项目..."
    
    if [ -d "$KUBESPRAY_DIR" ]; then
        log_warning "kubespray 目录已存在，删除后重新克隆"
        rm -rf "$KUBESPRAY_DIR"
    fi
    
    cd "$(dirname "$PROJECT_ROOT")"
    git clone https://github.com/kubernetes-sigs/kubespray.git
    cd kubespray
    
    log_info "切换到 release-2.27 分支（更稳定的版本）..."
    git checkout release-2.27
    
    log_success "kubespray 项目克隆完成"
}

# 复制配置文件
copy_config_files() {
    log_info "复制配置文件..."
    
    cd "$KUBESPRAY_DIR"
    
    # 复制 inventory sample 到 mycluster
    if [ -d "inventory/sample" ]; then
        log_info "复制 inventory/sample 到 inventory/mycluster..."
        cp -r inventory/sample inventory/mycluster
    else
        log_error "inventory/sample 目录不存在"
        exit 1
    fi
    
    # 复制项目中的配置文件到 kubespray
    log_info "复制项目配置文件到 kubespray..."
    
    # 复制 inventory.ini
    if [ -f "$CONFIG_SOURCE_DIR/inventory.ini" ]; then
        log_info "复制 inventory.ini 从 $CONFIG_SOURCE_DIR/inventory.ini 到 $KUBESPRAY_DIR/inventory/mycluster/"
        cp "$CONFIG_SOURCE_DIR/inventory.ini" "$KUBESPRAY_DIR/inventory/mycluster/"
        log_success "复制 inventory.ini 完成"
    else
        log_error "源 inventory.ini 文件不存在: $CONFIG_SOURCE_DIR/inventory.ini"
        exit 1
    fi
    
    # 复制 group_vars 配置
    if [ -d "$CONFIG_SOURCE_DIR/group_vars" ]; then
        log_info "复制 group_vars 从 $CONFIG_SOURCE_DIR/group_vars 到 $KUBESPRAY_DIR/inventory/mycluster/"
        cp -r "$CONFIG_SOURCE_DIR/group_vars" "$KUBESPRAY_DIR/inventory/mycluster/"
        log_success "复制 group_vars 配置完成"
    else
        log_error "源 group_vars 目录不存在: $CONFIG_SOURCE_DIR/group_vars"
        exit 1
    fi
    
    log_success "配置文件复制完成"
}

# 安装依赖
install_dependencies() {
    log_info "安装 kubespray 依赖..."
    
    cd "$(dirname "$PROJECT_ROOT")"
    
    # 创建 Python 虚拟环境
    log_info "创建 Python 虚拟环境..."
    python3 -m venv $VENVDIR
    
    # 激活虚拟环境
    log_info "激活虚拟环境..."
    source $VENVDIR/bin/activate
    
    # 进入 kubespray 目录
    cd $KUBESPRAYDIR
    
    # 安装 Python 依赖
    if [ -f "requirements.txt" ]; then
        log_info "安装 Python 依赖..."
        pip install -U -r requirements.txt
    fi
    
    log_success "依赖安装完成"
}

# 执行集群安装
install_cluster() {
    log_info "开始安装 Kubernetes 集群..."
    
    cd "$(dirname "$PROJECT_ROOT")"
    
    # 确保虚拟环境已激活
    log_info "激活虚拟环境..."
    source $VENVDIR/bin/activate
    
    # 进入 kubespray 目录
    cd $KUBESPRAYDIR
    
    # 检查 inventory 文件是否存在
    if [ ! -f "inventory/mycluster/inventory.ini" ]; then
        log_error "inventory.ini 文件不存在"
        exit 1
    fi
    
    log_info "执行 ansible-playbook 命令..."
    log_info "命令: ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v"
    
    # 执行安装
    ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b -v
    
    if [ $? -eq 0 ]; then
        log_success "Kubernetes 集群安装完成！"
    else
        log_error "集群安装失败"
        exit 1
    fi
}

# 集群安装后修复
post_install_fixes() {
    log_info "执行集群安装后修复..."
    
    # 修复 cilium-operator 副本数（单节点集群）
    log_info "修复 cilium-operator 副本数..."
    kubectl scale deploy -n kube-system cilium-operator --replicas=1
    
    log_success "集群安装后修复完成"
}

# 配置 iptables 端口转发
configure_iptables() {
    log_info "开始配置 iptables 端口转发..."
    
    # 检查 HTTP 端口转发规则是否已存在
    if iptables -t nat -C PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 30080 2>/dev/null; then
        log_info "HTTP 端口转发规则 (80 -> 30080) 已存在，跳过添加"
    else
        log_info "添加 HTTP 端口转发规则 (80 -> 30080)..."
        iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 30080
    fi
    
    # 检查 HTTPS 端口转发规则是否已存在
    if iptables -t nat -C PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 30443 2>/dev/null; then
        log_info "HTTPS 端口转发规则 (443 -> 30443) 已存在，跳过添加"
    else
        log_info "添加 HTTPS 端口转发规则 (443 -> 30443)..."
        iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 30443
    fi
    
    # 保存 iptables 规则（Ubuntu/Debian）
    if command -v iptables-save &> /dev/null; then
        log_info "保存 iptables 规则..."
        
        # 创建 iptables 目录（如果不存在）
        if [ ! -d "/etc/iptables" ]; then
            log_info "创建 /etc/iptables 目录..."
            mkdir -p /etc/iptables
        fi
        
        # 保存规则
        iptables-save > /etc/iptables/rules.v4
        
        # 安装 iptables-persistent 来确保规则持久化
        if ! dpkg -l | grep -q iptables-persistent; then
            log_info "安装 iptables-persistent 来持久化规则..."
            apt install iptables-persistent -y
        fi
        
        log_success "iptables 规则已保存"
    fi
    
    log_success "iptables 端口转发配置完成"
}

# 显示安装后的信息
show_post_install_info() {
    log_info "安装完成后的操作建议："
    echo ""
    echo "1. 配置 kubectl:"
    echo "   cp $KUBESPRAY_DIR/inventory/mycluster/artifacts/admin.conf ~/.kube/config"
    echo ""
    echo "2. 验证集群状态:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods --all-namespaces"
    echo ""
    echo "3. 验证 iptables 规则:"
    echo "   iptables -t nat -L PREROUTING -n --line-numbers"
    echo "   curl -I http://localhost:80"
    echo "   curl -I https://localhost:443"
    echo ""
    echo "4. 如果需要重置集群:"
    echo "   cd $KUBESPRAY_DIR"
    echo "   ansible-playbook -i inventory/mycluster/inventory.ini reset.yml -b -v"
    echo ""
}

# 主函数
main() {
    log_info "开始 Kubernetes 集群安装流程..."
    
    system_update
    clone_kubespray
    copy_config_files
    install_dependencies
    install_cluster
    post_install_fixes
    configure_iptables
    show_post_install_info
    
    log_success "安装脚本执行完成！"
}

# 执行主函数
main "$@"
