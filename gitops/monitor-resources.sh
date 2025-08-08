#!/bin/bash

# 集群资源监控脚本
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

# 检查节点资源
check_node_resources() {
    log_info "检查节点资源使用情况..."
    echo ""
    
    # 获取节点信息
    kubectl top nodes
    
    echo ""
    log_info "节点详细信息："
    kubectl describe nodes | grep -A 10 "Allocated resources"
}

# 检查 Pod 资源使用
check_pod_resources() {
    log_info "检查 Pod 资源使用情况..."
    echo ""
    
    # 按命名空间显示资源使用
    kubectl top pods --all-namespaces --sort-by=cpu
    
    echo ""
    log_info "资源使用最多的 Pod："
    kubectl top pods --all-namespaces --sort-by=cpu | head -10
    
    echo ""
    log_info "Istio 相关 Pod 资源使用："
    kubectl top pods -n istio-system --sort-by=cpu
}

# 检查命名空间资源配额
check_namespace_quotas() {
    log_info "检查命名空间资源配额..."
    echo ""
    
    kubectl get resourcequota --all-namespaces
}

# 计算资源使用百分比
calculate_usage() {
    log_info "计算资源使用百分比..."
    echo ""
    
    # 获取集群总资源
    total_cpu=$(kubectl describe nodes | grep -A 5 "Allocated resources" | grep "cpu" | awk '{print $2}' | sed 's/m//' | awk '{sum += $1} END {print sum}')
    total_memory=$(kubectl describe nodes | grep -A 5 "Allocated resources" | grep "memory" | awk '{print $2}' | sed 's/Ki//' | awk '{sum += $1} END {print sum}')
    
    # 获取已使用资源
    used_cpu=$(kubectl top nodes | tail -n +2 | awk '{sum += $3} END {print sum}' | sed 's/m//')
    used_memory=$(kubectl top nodes | tail -n +2 | awk '{sum += $4} END {print sum}' | sed 's/Mi//')
    
    # 计算百分比
    cpu_percent=$(echo "scale=2; $used_cpu * 100 / $total_cpu" | bc)
    memory_percent=$(echo "scale=2; $used_memory * 100 / $total_memory" | bc)
    
    echo "CPU 使用率: ${cpu_percent}%"
    echo "内存使用率: ${memory_percent}%"
    
    # 警告阈值
    if (( $(echo "$cpu_percent > 80" | bc -l) )); then
        log_warning "CPU 使用率过高: ${cpu_percent}%"
    fi
    
    if (( $(echo "$memory_percent > 80" | bc -l) )); then
        log_warning "内存使用率过高: ${memory_percent}%"
    fi
}

# 显示资源建议
show_recommendations() {
    log_info "资源优化建议："
    echo ""
    echo "1. 如果 CPU 使用率 > 80%："
    echo "   - 考虑减少非关键组件的副本数"
    echo "   - 调整资源限制"
    echo "   - 关闭不必要的功能（如 tracing）"
    echo ""
    echo "2. 如果内存使用率 > 80%："
    echo "   - 减少 Prometheus 数据保留时间"
    echo "   - 调整 JVM 堆大小"
    echo "   - 考虑使用更轻量的镜像"
    echo ""
    echo "3. 当前配置优化："
    echo "   - Istio: 单副本，禁用 egress gateway，最小化 sidecar"
    echo "   - Prometheus: 30s 抓取间隔，24h 保留"
    echo "   - Grafana: 最小资源分配"
    echo ""
    echo "4. 为业务应用预留资源："
    echo "   - CPU: ~1.7 核"
    echo "   - 内存: ~5GB"
    echo ""
    echo "5. Istio 优化措施："
    echo "   - Sidecar CPU: 25m-200m (原 50m-500m)"
    echo "   - Sidecar 内存: 32Mi-128Mi (原 64Mi-256Mi)"
    echo "   - Pilot CPU: 100m-200m (原 200m-500m)"
    echo "   - Ingress Gateway: 50m-150m (原 100m-300m)"
}

# 主函数
main() {
    log_info "开始检查集群资源使用情况..."
    echo ""
    
    check_node_resources
    echo ""
    check_pod_resources
    echo ""
    check_namespace_quotas
    echo ""
    calculate_usage
    echo ""
    show_recommendations
    
    log_success "资源检查完成！"
}

# 执行主函数
main "$@" 