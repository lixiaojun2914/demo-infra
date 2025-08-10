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

# 检查基础网络
check_basic_network() {
    log_info "=== 检查基础网络连通性 ==="
    
    # 检查本地网络接口
    log_info "检查本地网络接口..."
    ip addr show | grep -E "inet.*scope global" || log_warning "未找到全局网络接口"
    
    # 检查默认网关
    log_info "检查默认网关..."
    ip route show default || log_warning "未找到默认路由"
    
    # 检查 DNS 解析
    log_info "检查 DNS 解析..."
    if nslookup lixiaojun.io &> /dev/null; then
        log_success "DNS 解析正常: lixiaojun.io"
    else
        log_error "DNS 解析失败: lixiaojun.io"
    fi
    
    # 检查外部网络连通性
    log_info "检查外部网络连通性..."
    if ping -c 3 8.8.8.8 &> /dev/null; then
        log_success "外部网络连通性正常"
    else
        log_error "外部网络连通性异常"
    fi
}

# 检查 Kubernetes 集群网络
check_k8s_network() {
    log_info "=== 检查 Kubernetes 集群网络 ==="
    
    # 检查 kubectl 连接
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装"
        return 1
    fi
    
    # 检查集群连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到 Kubernetes 集群"
        return 1
    fi
    
    log_success "Kubernetes 集群连接正常"
    
    # 检查节点状态
    log_info "检查节点状态..."
    kubectl get nodes -o wide
    
    # 检查 Pod 网络
    log_info "检查 Pod 网络..."
    kubectl get pods --all-namespaces -o wide | head -10
    
    # 检查服务网络
    log_info "检查服务网络..."
    kubectl get svc --all-namespaces | head -10
}

# 检查 Istio 网络
check_istio_network() {
    log_info "=== 检查 Istio 网络 ==="
    
    # 检查 Istio 命名空间
    if kubectl get namespace istio-system &> /dev/null; then
        log_success "Istio 命名空间存在"
    else
        log_error "Istio 命名空间不存在"
        return 1
    fi
    
    # 检查 Istio Gateway
    log_info "检查 Istio Gateway..."
    kubectl get gateway -n istio-system
    
    # 检查 Istio IngressGateway
    log_info "检查 Istio IngressGateway..."
    kubectl get pods -n istio-system -l app=istio-ingressgateway
    
    # 检查 IngressGateway 服务
    log_info "检查 IngressGateway 服务..."
    kubectl get svc -n istio-system -l app=istio-ingressgateway
    
    # 检查 IngressGateway 端口映射
    log_info "检查 IngressGateway 端口映射..."
    kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[*]}' | jq -r '.nodePort' 2>/dev/null || log_warning "无法获取 NodePort 信息"
}

# 检查 Nginx 配置和状态
check_nginx_status() {
    log_info "=== 检查 Nginx 状态 ==="
    
    # 检查 nginx 进程
    if pgrep nginx &> /dev/null; then
        log_success "Nginx 进程正在运行"
    else
        log_error "Nginx 进程未运行"
        return 1
    fi
    
    # 检查 nginx 服务状态
    if systemctl is-active --quiet nginx; then
        log_success "Nginx 服务状态正常"
    else
        log_error "Nginx 服务状态异常"
    fi
    
    # 检查 nginx 配置
    if nginx -t &> /dev/null; then
        log_success "Nginx 配置语法正确"
    else
        log_error "Nginx 配置语法错误"
    fi
    
    # 检查 nginx 监听端口
    log_info "检查 Nginx 监听端口..."
    netstat -tlnp | grep nginx || ss -tlnp | grep nginx || log_warning "无法获取 Nginx 端口信息"
}

# 检查端口连通性
check_port_connectivity() {
    log_info "=== 检查端口连通性 ==="
    
    # 检查本地端口监听
    log_info "检查本地端口监听状态..."
    
    # 检查 80 端口
    if netstat -tln | grep ":80 " &> /dev/null || ss -tln | grep ":80 " &> /dev/null; then
        log_success "端口 80 正在监听"
    else
        log_error "端口 80 未监听"
    fi
    
    # 检查 443 端口
    if netstat -tln | grep ":443 " &> /dev/null || ss -tln | grep ":443 " &> /dev/null; then
        log_success "端口 443 正在监听"
    else
        log_error "端口 443 未监听"
    fi
    
    # 检查 Istio NodePort
    log_info "检查 Istio NodePort 连通性..."
    
    # 检查 30080 端口（HTTP）
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:30080 &> /dev/null; then
        log_success "Istio HTTP NodePort (30080) 可访问"
    else
        log_error "Istio HTTP NodePort (30080) 不可访问"
    fi
    
    # 检查 30443 端口（HTTPS）
    if curl -s -o /dev/null -w "%{http_code}" -k https://localhost:30443 &> /dev/null; then
        log_success "Istio HTTPS NodePort (30443) 可访问"
    else
        log_error "Istio HTTPS NodePort (30443) 不可访问"
    fi
}

# 检查服务路由
check_service_routing() {
    log_info "=== 检查服务路由 ==="
    
    # 检查 Istio VirtualServices
    log_info "检查 Istio VirtualServices..."
    kubectl get virtualservice --all-namespaces
    
    # 检查 Istio DestinationRules
    log_info "检查 Istio DestinationRules..."
    kubectl get destinationrule --all-namespaces
    
    # 检查 Istio 服务网格状态
    log_info "检查 Istio 服务网格状态..."
    istioctl analyze --all-namespaces 2>/dev/null || log_warning "istioctl 不可用，跳过服务网格分析"
}

# 检查防火墙和网络策略
check_firewall_network_policy() {
    log_info "=== 检查防火墙和网络策略 ==="
    
    # 检查 UFW 状态
    if command -v ufw &> /dev/null; then
        log_info "检查 UFW 防火墙状态..."
        ufw status
    else
        log_warning "UFW 未安装"
    fi
    
    # 检查 iptables 规则
    log_info "检查 iptables 规则..."
    iptables -L -n | grep -E "(80|443|30080|30443)" || log_warning "未找到相关 iptables 规则"
    
    # 检查 Kubernetes 网络策略
    log_info "检查 Kubernetes 网络策略..."
    kubectl get networkpolicy --all-namespaces
}

# 检查证书状态
check_certificate_status() {
    log_info "=== 检查证书状态 ==="
    
    # 检查 cert-manager
    if kubectl get namespace cert-manager &> /dev/null; then
        log_info "检查 cert-manager 状态..."
        kubectl get pods -n cert-manager
        
        # 检查 ClusterIssuer
        log_info "检查 ClusterIssuer..."
        kubectl get clusterissuer
        
        # 检查证书
        log_info "检查证书状态..."
        kubectl get certificate --all-namespaces
    else
        log_warning "cert-manager 命名空间不存在"
    fi
}

# 执行网络测试
run_network_tests() {
    log_info "=== 执行网络测试 ==="
    
    # 测试本地 HTTP 访问
    log_info "测试本地 HTTP 访问..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost &> /dev/null; then
        log_success "本地 HTTP 访问正常"
    else
        log_error "本地 HTTP 访问失败"
    fi
    
    # 测试本地 HTTPS 访问
    log_info "测试本地 HTTPS 访问..."
    if curl -s -o /dev/null -w "%{http_code}" -k https://localhost &> /dev/null; then
        log_success "本地 HTTPS 访问正常"
    else
        log_error "本地 HTTPS 访问失败"
    fi
    
    # 测试域名访问（需要 DNS 解析）
    log_info "测试域名访问..."
    if curl -s -o /dev/null -w "%{http_code}" http://lixiaojun.io &> /dev/null; then
        log_success "域名 HTTP 访问正常"
    else
        log_warning "域名 HTTP 访问失败（可能是 DNS 或网络问题）"
    fi
}

# 生成网络状态报告
generate_network_report() {
    log_info "=== 生成网络状态报告 ==="
    
    echo ""
    echo "📊 网络连通性检查报告"
    echo "========================"
    echo "检查时间: $(date)"
    echo "主机名: $(hostname)"
    echo "IP 地址: $(hostname -I | awk '{print $1}')"
    echo ""
    
    # 基础网络状态
    echo "🌐 基础网络状态:"
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "  ✅ 外部网络连通性正常"
    else
        echo "  ❌ 外部网络连通性异常"
    fi
    
    # Kubernetes 状态
    echo ""
    echo "☸️  Kubernetes 状态:"
    if kubectl cluster-info &> /dev/null; then
        echo "  ✅ 集群连接正常"
        echo "  📊 节点数量: $(kubectl get nodes --no-headers | wc -l)"
        echo "  📊 Pod 数量: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
    else
        echo "  ❌ 集群连接异常"
    fi
    
    # Istio 状态
    echo ""
    echo "🚀 Istio 状态:"
    if kubectl get namespace istio-system &> /dev/null; then
        echo "  ✅ Istio 命名空间存在"
        echo "  📊 Gateway 数量: $(kubectl get gateway -n istio-system --no-headers | wc -l)"
        echo "  📊 IngressGateway Pods: $(kubectl get pods -n istio-system -l app=istio-ingressgateway --no-headers | wc -l)"
    else
        echo "  ❌ Istio 命名空间不存在"
    fi
    
    # Nginx 状态
    echo ""
    echo "🔧 Nginx 状态:"
    if systemctl is-active --quiet nginx; then
        echo "  ✅ Nginx 服务运行正常"
        echo "  📊 监听端口: 80, 443"
    else
        echo "  ❌ Nginx 服务异常"
    fi
    
    # 端口连通性
    echo ""
    echo "🔌 端口连通性:"
    if netstat -tln | grep ":80 " &> /dev/null; then
        echo "  ✅ 端口 80 监听正常"
    else
        echo "  ❌ 端口 80 未监听"
    fi
    
    if netstat -tln | grep ":443 " &> /dev/null; then
        echo "  ✅ 端口 443 监听正常"
    else
        echo "  ❌ 端口 443 未监听"
    fi
}

# 主函数
main() {
    log_info "开始网络连通性检查..."
    echo ""
    
    check_basic_network
    echo ""
    
    check_k8s_network
    echo ""
    
    check_istio_network
    echo ""
    
    check_nginx_status
    echo ""
    
    check_port_connectivity
    echo ""
    
    check_service_routing
    echo ""
    
    check_firewall_network_policy
    echo ""
    
    check_certificate_status
    echo ""
    
    run_network_tests
    echo ""
    
    generate_network_report
    
    log_success "网络连通性检查完成！"
}

# 执行主函数
main "$@"
