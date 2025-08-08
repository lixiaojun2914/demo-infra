#!/bin/bash

# 设置 Istio Gateway 端口转发的脚本
# 自动读取 NodePort 并设置 iptables 规则

set -e

echo "=== Istio Gateway 端口转发设置脚本 ==="

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行此脚本"
    exit 1
fi

# 获取 Istio Gateway 的 NodePort
echo "正在获取 Istio Gateway 的 NodePort..."

# 获取 HTTP 端口 (80 -> NodePort)
HTTP_NODEPORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

# 获取 HTTPS 端口 (443 -> NodePort)
HTTPS_NODEPORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')

if [ -z "$HTTP_NODEPORT" ] || [ -z "$HTTPS_NODEPORT" ]; then
    echo "错误: 无法获取 NodePort 值"
    echo "HTTP NodePort: $HTTP_NODEPORT"
    echo "HTTPS NodePort: $HTTPS_NODEPORT"
    exit 1
fi

echo "获取到的端口映射:"
echo "  HTTP (80) -> NodePort: $HTTP_NODEPORT"
echo "  HTTPS (443) -> NodePort: $HTTPS_NODEPORT"

# 删除现有的端口转发规则
echo "正在删除现有的端口转发规则..."
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port $HTTP_NODEPORT 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port $HTTPS_NODEPORT 2>/dev/null || true

# 添加新的端口转发规则
echo "正在添加新的端口转发规则..."
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port $HTTP_NODEPORT
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port $HTTPS_NODEPORT

# 验证规则是否添加成功
echo "验证端口转发规则..."
iptables -t nat -L PREROUTING -n --line-numbers | grep -E "(80|443)"

echo ""
echo "=== 端口转发设置完成 ==="
echo "现在可以通过以下地址访问:"
echo "  HTTP:  http://lixiaojun.io/postgresql-ui"
echo "  HTTPS: https://lixiaojun.io/postgresql-ui"
echo ""
echo "注意: 请确保域名 lixiaojun.io 已解析到当前服务器 IP"
echo ""
echo "要保存 iptables 规则，请运行:"
echo "  sudo iptables-save > /etc/iptables/rules.v4"
echo "或"
echo "  sudo iptables-save > /etc/iptables/rules.v4" 