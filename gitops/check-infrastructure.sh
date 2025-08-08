#!/bin/bash

# 基础设施状态检查脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

# 检查命名空间
check_namespaces() {
    log_info "检查命名空间状态..."
    
    namespaces=("argocd" "istio-system" "monitoring" "logging" "cert-manager" "metallb-system" "longhorn-system")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_success "命名空间 $ns 存在"
        else
            log_error "命名空间 $ns 不存在"
        fi
    done
}

# 检查 Pod 状态
check_pods() {
    log_info "检查 Pod 状态..."
    
    # 检查所有命名空间的 Pod
    kubectl get pods --all-namespaces --field-selector=status.phase!=Running
    
    # 检查特定应用的 Pod
    apps=(
        "argocd/argocd-server"
        "monitoring/prometheus"
        "monitoring/grafana"
        "cert-manager/cert-manager"
        "metallb-system/metallb-controller"
    )
    
    for app in "${apps[@]}"; do
        ns=$(echo "$app" | cut -d'/' -f1)
        name=$(echo "$app" | cut -d'/' -f2)
        
        if kubectl get deployment "$name" -n "$ns" &> /dev/null; then
            ready=$(kubectl get deployment "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}')
            desired=$(kubectl get deployment "$name" -n "$ns" -o jsonpath='{.spec.replicas}')
            
            if [ "$ready" = "$desired" ]; then
                log_success "$app 运行正常 ($ready/$desired)"
            else
                log_warning "$app 未完全就绪 ($ready/$desired)"
            fi
        else
            log_error "$app 不存在"
        fi
    done
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    services=(
        "argocd/argocd-server"
        "monitoring/prometheus"
        "monitoring/grafana"
        "cert-manager/cert-manager-webhook"
    )
    
    for svc in "${services[@]}"; do
        ns=$(echo "$svc" | cut -d'/' -f1)
        name=$(echo "$svc" | cut -d'/' -f2)
        
        if kubectl get service "$name" -n "$ns" &> /dev/null; then
            log_success "服务 $svc 存在"
        else
            log_error "服务 $svc 不存在"
        fi
    done
}

# 检查 ArgoCD 应用状态
check_argocd_apps() {
    log_info "检查 ArgoCD 应用状态..."
    
    if kubectl get applications -n argocd &> /dev/null; then
        log_info "ArgoCD 应用列表："
        kubectl get applications -n argocd
    else
        log_error "无法获取 ArgoCD 应用列表"
    fi
}

# 检查存储类
check_storage_classes() {
    log_info "检查存储类..."
    
    if kubectl get storageclass &> /dev/null; then
        log_info "存储类列表："
        kubectl get storageclass
    else
        log_error "无法获取存储类列表"
    fi
}

# 检查证书颁发者
check_issuers() {
    log_info "检查证书颁发者..."
    
    if kubectl get clusterissuer &> /dev/null; then
        log_info "集群证书颁发者："
        kubectl get clusterissuer
    else
        log_error "无法获取证书颁发者"
    fi
}

# 检查网络策略
check_network_policies() {
    log_info "检查网络策略..."
    
    if kubectl get networkpolicies --all-namespaces &> /dev/null; then
        log_info "网络策略列表："
        kubectl get networkpolicies --all-namespaces
    else
        log_warning "没有找到网络策略"
    fi
}

# 主函数
main() {
    log_info "开始检查基础设施状态..."
    
    check_namespaces
    echo ""
    check_pods
    echo ""
    check_services
    echo ""
    check_argocd_apps
    echo ""
    check_storage_classes
    echo ""
    check_issuers
    echo ""
    check_network_policies
    
    log_success "基础设施状态检查完成！"
}

# 执行主函数
main "$@" 