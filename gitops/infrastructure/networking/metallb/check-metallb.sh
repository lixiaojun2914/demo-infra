#!/bin/bash

# MetalLB 状态检查脚本
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 检查 MetalLB 组件状态
check_metallb_components() {
    log_info "检查 MetalLB 组件状态..."
    
    # 检查命名空间
    if kubectl get namespace metallb-system &> /dev/null; then
        log_success "metallb-system 命名空间存在"
    else
        log_error "metallb-system 命名空间不存在"
        return 1
    fi
    
    # 检查 Pod 状态
    log_info "检查 MetalLB Pod 状态..."
    kubectl get pods -n metallb-system
    
    # 检查 IPAddressPool
    if kubectl get ipaddresspool default-pool -n metallb-system &> /dev/null; then
        log_success "default-pool IPAddressPool 存在"
    else
        log_error "default-pool IPAddressPool 不存在"
        return 1
    fi
    
    # 检查 L2Advertisement
    if kubectl get l2advertisement default-l2advertisement -n metallb-system &> /dev/null; then
        log_success "default-l2advertisement L2Advertisement 存在"
    else
        log_error "default-l2advertisement L2Advertisement 不存在"
        return 1
    fi
}

# 检查 IP 地址池配置
check_address_pools() {
    log_info "检查 IP 地址池配置..."
    
    kubectl get ipaddresspool default-pool -n metallb-system -o yaml
    
    echo ""
    log_info "当前配置的 IP 地址池："
    echo "  - 默认池: 195.35.37.243"
}

# 检查 LoadBalancer 服务
check_loadbalancer_services() {
    log_info "检查 LoadBalancer 服务..."
    
    # 检查所有 LoadBalancer 类型的服务
    kubectl get services --all-namespaces -o wide | grep LoadBalancer
    
    echo ""
    log_info "检查服务的外部 IP 分配..."
    
    # 获取所有 LoadBalancer 服务的外部 IP
    services=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')
    
    if [ -n "$services" ]; then
        for service in $services; do
            namespace=$(echo "$service" | cut -d'/' -f1)
            name=$(echo "$service" | cut -d'/' -f2)
            external_ip=$(kubectl get service "$name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            if [ -n "$external_ip" ]; then
                log_success "$namespace/$name 外部 IP: $external_ip"
            else
                log_warning "$namespace/$name 尚未分配外部 IP"
            fi
        done
    else
        log_info "当前没有 LoadBalancer 类型的服务"
    fi
}

# 检查网络连通性
check_network_connectivity() {
    log_info "检查网络连通性..."
    
    # 获取所有外部 IP
    external_ips=$(kubectl get services --all-namespaces -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}')
    
    if [ -n "$external_ips" ]; then
        for ip in $external_ips; do
            if ping -c 1 -W 2 "$ip" &> /dev/null; then
                log_success "IP $ip 可达"
            else
                log_warning "IP $ip 不可达"
            fi
        done
    else
        log_warning "没有找到外部 IP"
    fi
}

# 显示使用说明
show_usage_info() {
    log_info "MetalLB 使用说明："
    echo ""
    echo "1. 为服务分配外部 IP："
    echo "   在 Service 的 metadata.annotations 中添加："
    echo "   metallb.universe.tf/address-pool: default"
    echo "   注意：所有服务将共享同一个 IP (195.35.37.243)，通过不同端口访问"
    echo ""
    echo "2. 检查服务状态："
    echo "   kubectl get services --all-namespaces | grep LoadBalancer"
    echo ""
    echo "3. 查看外部 IP："
    echo "   kubectl get service <service-name> -n <namespace> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
    echo ""
    echo "4. 访问服务："
    echo "   curl http://<external-ip>:<port>"
}

# 主函数
main() {
    log_info "开始检查 MetalLB 状态..."
    echo ""
    
    check_metallb_components
    echo ""
    check_address_pools
    echo ""
    check_loadbalancer_services
    echo ""
    check_network_connectivity
    echo ""
    show_usage_info
    
    log_success "MetalLB 状态检查完成！"
}

# 执行主函数
main "$@" 