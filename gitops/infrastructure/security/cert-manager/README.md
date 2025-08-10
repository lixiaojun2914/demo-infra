# Cert-Manager 配置

这个目录包含了 cert-manager 的配置资源，用于为 Istio Gateway 提供自动 TLS 证书管理。

## 文件说明

### `letsencrypt-issuer.yaml`
- **ClusterIssuer**: 配置 Let's Encrypt 证书颁发机构
- **letsencrypt-prod**: 生产环境证书颁发者
- **letsencrypt-staging**: 测试环境证书颁发者（用于开发测试）
- **Istio 集成**: 使用 Istio Gateway 进行 HTTP-01 验证

### `certificate.yaml`
- **demo-tls-cert**: 为 `lixiaojun.io` 域名生成 TLS 证书
- **demo-tls-cert-staging**: 测试环境证书
- **自动续期**: 证书在过期前 15 天自动续期

### `kustomization.yaml`
- 管理 cert-manager 配置资源
- 应用通用标签

## 部署方式

### 通过 ArgoCD 部署（推荐）
```bash
# 应用 ArgoCD Application
kubectl apply -f ../../argocd/applications/cert-manager-config.yaml
```

### 手动部署（仅用于测试）
```bash
# 应用 ClusterIssuer
kubectl apply -f letsencrypt-issuer.yaml

# 应用证书
kubectl apply -f certificate.yaml
```

## 配置说明

### 域名配置
- **主域名**: `lixiaojun.io`
- **通配符**: `*.lixiaojun.io`
- **证书类型**: 多域名证书

### 证书参数
- **有效期**: 90 天
- **续期时间**: 过期前 15 天
- **颁发者**: Let's Encrypt

### 环境选择
- **生产环境**: 使用 `letsencrypt-prod` ClusterIssuer
- **测试环境**: 使用 `letsencrypt-staging` ClusterIssuer

### Istio 集成
- **验证方式**: HTTP-01 通过 Istio Gateway
- **Gateway 引用**: `istio-system/demo-gateway`
- **自动验证**: cert-manager 通过 Istio 自动完成域名验证

## 验证证书

### 检查证书状态
```bash
# 检查证书
kubectl get certificate -n istio-system

# 查看证书详情
kubectl describe certificate demo-tls-cert -n istio-system

# 检查 TLS Secret
kubectl get secret demo-tls-cert -n istio-system
```

### 检查 ClusterIssuer
```bash
# 查看 ClusterIssuer 状态
kubectl get clusterissuer

# 查看 ClusterIssuer 详情
kubectl describe clusterissuer letsencrypt-prod
```

### 使用检查脚本
```bash
# 运行检查脚本
./scripts/check-certificates.sh
```

## 故障排除

### 常见问题

1. **证书验证失败**
   - 检查域名 DNS 解析是否正确
   - 确认 Istio Gateway 配置正确
   - 检查 cert-manager 日志

2. **证书未生成**
   - 检查 ClusterIssuer 状态
   - 查看 cert-manager 事件
   - 确认 Istio Gateway 配置正确

3. **证书过期**
   - 检查 cert-manager 是否正常运行
   - 查看证书续期事件
   - 手动触发证书续期

### 日志查看
```bash
# 查看 cert-manager 日志
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# 查看证书相关事件
kubectl get events -n istio-system --sort-by='.lastTimestamp' | grep -i certificate
```

## 注意事项

1. **Let's Encrypt 限制**
   - 每个域名每周最多 50 个证书
   - 每个证书最多 100 个域名
   - 测试环境无限制

2. **安全考虑**
   - 生产环境使用 `letsencrypt-prod`
   - 定期检查证书状态
   - 监控证书续期失败

3. **网络要求**
   - 80 端口必须可访问（HTTP-01 验证通过 Istio）
   - 443 端口用于 HTTPS 服务
   - 确保 Istio Gateway 配置正确

4. **Istio 依赖**
   - 需要 Istio Gateway 正常运行
   - Gateway 必须配置 HTTP 端口用于验证
   - 确保 Istio IngressGateway 可访问

## 相关资源

- [Cert-Manager 官方文档](https://cert-manager.io/docs/)
- [Let's Encrypt 文档](https://letsencrypt.org/docs/)
- [Istio Gateway 配置](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [Cert-Manager Istio 集成](https://cert-manager.io/docs/configuration/acme/http01/istio/)
