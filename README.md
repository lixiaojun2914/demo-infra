# Demo Infrastructure

这是一个基于 GitOps 的 Kubernetes 基础设施管理项目，使用 ArgoCD 进行自动化部署和管理。

## 🏗️ 项目结构

```
demo-infra/
├── cluster-bootstrap/          # 集群安装相关
│   ├── kubespray/             # kubespray 配置
│   └── scripts/               # 安装脚本
└── gitops/                     # GitOps 配置
    ├── infrastructure/         # 基础设施层
    │   ├── istio/             # 服务网格
    │   ├── monitoring/        # 监控栈
    │   ├── networking/        # 网络配置
    │   ├── security/          # 安全组件
    │   └── storage/           # 存储组件
    ├── applications/          # 业务应用层
    ├── argocd/                # ArgoCD 配置
    └── base/                  # 基础配置
```

## 🚀 快速开始

### 1. 集群安装

```bash
# 运行集群安装脚本
cd cluster-bootstrap/scripts
./install-cluster.sh
```

### 2. 基础设施部署

```bash
# 部署基础设施组件
kubectl apply -f gitops/base/
kubectl apply -f gitops/infrastructure/
```

### 3. 访问服务

- **ArgoCD**: http://your-server-ip:8080
- **Grafana**: http://your-server-ip:3000
- **Istio Gateway**: http://your-server-ip:80

## 📋 组件说明

### 基础设施层

- **Istio**: 服务网格，提供流量管理、安全、可观测性
- **MetalLB**: 负载均衡器，为服务分配外部 IP
- **Prometheus + Grafana**: 监控和可视化
- **Cert-Manager**: 证书管理
- **Longhorn**: 分布式存储

### 业务应用层

- **开发环境**: auth-service, chat-service 等
- **预发布环境**: 与开发环境相同的服务
- **生产环境**: 生产级别的配置

## 🔧 环境配置

### 开发环境 (2核8G 优化)

- 最小资源消耗
- 单副本部署
- 禁用不必要的功能

### 生产环境

- 高可用配置
- 多副本部署
- 完整功能启用

## 📖 使用指南

### 添加新服务

1. 在 `gitops/applications/` 下创建服务配置
2. 更新 ArgoCD ApplicationSet
3. 推送代码，ArgoCD 自动部署

### 修改配置

1. 编辑相应的 YAML 文件
2. 提交并推送代码
3. ArgoCD 自动同步变更

## 🛠️ 维护

### 检查集群状态

```bash
# 检查基础设施状态
./gitops/check-infrastructure.sh

# 检查资源使用
./gitops/monitor-resources.sh
```

### 故障排除

- 查看 ArgoCD 应用状态
- 检查 Pod 日志
- 验证网络连通性

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！ 