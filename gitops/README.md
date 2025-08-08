# Demo Infrastructure GitOps

这是一个基于 ArgoCD 的 GitOps 项目，用于管理 Kubernetes 集群的基础设施和业务应用。

## 项目结构

```
demo-infra/
├── cluster-bootstrap/          # 集群安装相关
│   ├── kubespray/             # kubespray 配置
│   └── scripts/               # 安装脚本
└── gitops/                     # GitOps 配置
    ├── infrastructure/         # 基础设施层（运维应用）
    │   ├── argocd/            # ArgoCD 自身配置
    │   ├── istio/             # 服务网格
    │   ├── monitoring/        # 监控栈
    │   ├── logging/           # 日志栈
    │   ├── security/          # 安全相关
    │   ├── storage/           # 存储相关
    │   └── networking/        # 网络相关
    ├── applications/          # 业务应用层
    │   ├── dev/              # 开发环境
    │   ├── staging/          # 预发布环境
    │   └── prod/             # 生产环境
    ├── argocd/                # ArgoCD 项目和应用集配置
    │   ├── projects/         # 项目定义
    │   └── applicationsets/  # 应用集定义
    └── base/                  # 基础配置和模板
```

## 核心概念

### 1. 基础设施层 (Infrastructure)
- **监控栈**: Prometheus, Grafana, AlertManager
- **日志栈**: Elasticsearch, Fluentd, Kibana
- **服务网格**: Istio
- **安全**: Cert-Manager, Vault
- **存储**: Longhorn
- **网络**: MetalLB

### 2. 业务应用层 (Applications)
- **开发环境**: auth-service, chat-service, document-service 等
- **预发布环境**: 与开发环境相同的服务，但配置不同
- **生产环境**: 生产级别的配置和资源分配

### 3. ArgoCD 配置
- **Projects**: 定义资源访问权限和命名空间
- **ApplicationSets**: 自动生成和管理应用

## 使用方法

### 1. 部署基础设施
```bash
# 应用 ArgoCD 项目配置
kubectl apply -f argocd/projects/

# 应用基础设施应用集
kubectl apply -f argocd/applicationsets/infrastructure-appset.yaml
```

### 2. 部署业务应用
```bash
# 应用业务应用集
kubectl apply -f argocd/applicationsets/applications-appset.yaml
```

### 3. 访问 ArgoCD UI
```bash
# 获取 ArgoCD 管理员密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 端口转发
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 环境分离策略

### 开发环境 (dev)
- 资源限制较低
- 日志级别为 debug
- 使用开发数据库
- 自动同步策略

### 预发布环境 (staging)
- 资源限制中等
- 日志级别为 info
- 使用预发布数据库
- 手动同步策略

### 生产环境 (prod)
- 资源限制较高
- 日志级别为 warn/error
- 使用生产数据库
- 手动同步策略，需要审批

## 最佳实践

1. **环境隔离**: 不同环境使用不同的命名空间和资源配额
2. **配置管理**: 使用 Kustomize 进行环境特定的配置管理
3. **安全**: 使用 RBAC 限制不同项目的资源访问权限
4. **监控**: 所有应用都配置了监控和日志收集
5. **备份**: 重要数据配置了自动备份策略

## 故障排除

### 常见问题
1. **同步失败**: 检查 Git 仓库权限和网络连接
2. **资源不足**: 检查集群资源配额和限制
3. **配置错误**: 检查 YAML 语法和 Kustomize 配置

### 日志查看
```bash
# 查看 ArgoCD 日志
kubectl logs -n argocd deployment/argocd-server

# 查看应用日志
kubectl logs -n <namespace> deployment/<app-name>
``` 