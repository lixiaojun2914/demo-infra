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

# 检查证书状态
check_certificates() {
    log_info "检查 cert-manager 状态..."
    
    # 检查 cert-manager 命名空间
    if kubectl get namespace cert-manager &> /dev/null; then
        log_success "cert-manager 命名空间存在"
    else
        log_error "cert-manager 命名空间不存在"
        return 1
    fi
    
    # 检查 cert-manager pods
    log_info "检查 cert-manager pods..."
    kubectl get pods -n cert-manager
    
    # 检查 ClusterIssuer
    log_info "检查 ClusterIssuer..."
    kubectl get clusterissuer
    
    # 检查证书
    log_info "检查证书状态..."
    kubectl get certificate -n istio-system
    
    # 检查证书详情
    log_info "检查证书详情..."
    kubectl describe certificate demo-tls-cert -n istio-system
    
    # 检查 secret
    log_info "检查 TLS secret..."
    kubectl get secret demo-tls-cert -n istio-system -o yaml | grep -E "(tls\.crt|tls\.key|ca\.crt)"
    
    # 检查 Istio Gateway
    log_info "检查 Istio Gateway..."
    kubectl get gateway -n istio-system
    
    # 检查 Istio IngressGateway
    log_info "检查 Istio IngressGateway..."
    kubectl get pods -n istio-system -l app=istio-ingressgateway
}

# 检查证书验证
check_cert_validation() {
    log_info "检查证书验证状态..."
    
    # 获取证书事件
    kubectl get events -n istio-system --sort-by='.lastTimestamp' | grep -i certificate
    
    # 检查 cert-manager 日志
    log_info "检查 cert-manager 日志..."
    kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=20
}

# 主函数
main() {
    log_info "开始检查证书配置..."
    
    check_certificates
    echo ""
    check_cert_validation
    
    log_success "证书检查完成！"
}

# 执行主函数
main "$@"
