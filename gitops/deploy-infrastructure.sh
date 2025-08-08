#!/bin/bash

# 基础设施部署脚本
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

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
    
    log_info "Kubernetes 集群连接正常"
}

# 部署 ArgoCD 项目
deploy_projects() {
    log_info "部署 ArgoCD 项目配置..."
    kubectl apply -f argocd/projects/
    log_success "ArgoCD 项目配置部署完成"
}

# 部署基础设施应用集
deploy_infrastructure() {
    log_info "部署基础设施应用集..."
    kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml
    log_success "基础设施应用集部署完成"
}

# 等待应用就绪
wait_for_apps() {
    log_info "等待基础设施应用就绪..."
    
    # 等待 MetalLB
    log_info "等待 MetalLB 就绪..."
    kubectl wait --for=condition=available --timeout=300s deployment/metallb-controller -n metallb-system
    
    # 等待 Cert-Manager
    log_info "等待 Cert-Manager 就绪..."
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    
    # 等待 Prometheus
    log_info "等待 Prometheus 就绪..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
    
    # 等待 Grafana
    log_info "等待 Grafana 就绪..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
    
    log_success "所有基础设施应用已就绪"
}

# 显示访问信息
show_access_info() {
    log_info "基础设施部署完成！"
    echo ""
    echo "访问信息："
    echo "1. ArgoCD UI:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   用户名: admin"
    echo "   密码: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    echo "2. Grafana:"
    echo "   kubectl port-forward svc/grafana -n monitoring 3000:3000"
    echo "   用户名: admin"
    echo "   密码: admin123"
    echo ""
    echo "3. Prometheus:"
    echo "   kubectl port-forward svc/prometheus -n monitoring 9090:9090"
    echo ""
    echo "4. 检查应用状态:"
    echo "   kubectl get applications -n argocd"
    echo "   kubectl get pods --all-namespaces"
    echo ""
    echo "5. 监控资源使用:"
    echo "   ./monitor-resources.sh"
    echo ""
    echo "⚠️  重要提醒："
    echo "   - 当前配置针对 2核8G 服务器优化"
    echo "   - 为业务应用预留了 ~1.5核 CPU 和 ~4GB 内存"
    echo "   - 建议定期运行 ./monitor-resources.sh 检查资源使用"
}

# 主函数
main() {
    log_info "开始部署基础设施..."
    
    check_kubectl
    deploy_projects
    deploy_infrastructure
    wait_for_apps
    show_access_info
    
    log_success "基础设施部署完成！"
}

# 执行主函数
main "$@" 