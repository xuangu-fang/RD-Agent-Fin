# Docker 代理问题排查指南

## 常见错误

### 错误 1：无法连接到 Docker Hub（registry-1.docker.io）

**错误信息：**
```
BuildError: failed to resolve reference "docker.io/pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime": 
failed to do request: Head "https://registry-1.docker.io/v2/pytorch/pytorch/manifests/2.2.1-cuda12.1-cudnn8-runtime": 
dialing registry-1.docker.io:443 container via direct connection because disabled has no HTTPS proxy: 
connecting to registry-1.docker.io:443: dial tcp [2a03:2880:f10f:83:face:b00c:0:25de]:443: 
connectex: A connection attempt failed...
```

**原因：**
- Docker 配置中的 `noProxy` 包含了 `docker.io`，导致 Docker Hub 被排除在代理之外
- 直接连接 Docker Hub 失败（可能是 IPv6 连接问题或网络限制）

**解决方案：**

#### 方法 1：使用修复脚本（推荐）

```bash
bash scripts/fix_docker_proxy_noProxy.sh
```

#### 方法 2：手动修复

编辑 `~/.docker/config.json`，从 `noProxy` 中移除 `docker.io`：

```bash
# 修复前
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.19.32.1:7890",
      "httpsProxy": "http://172.19.32.1:7890",
      "noProxy": "localhost,127.0.0.1,docker.io"  # ❌ 问题在这里
    }
  }
}

# 修复后
{
  "proxies": {
    "default": {
      "httpProxy": "http://172.19.32.1:7890",
      "httpsProxy": "http://172.19.32.1:7890",
      "noProxy": "localhost,127.0.0.1"  # ✅ 已移除 docker.io
    }
  }
}
```

#### 方法 3：使用 Python 脚本修复

```bash
python3 << 'EOF'
import json

config_file = f"{os.environ['HOME']}/.docker/config.json"
with open(config_file, 'r') as f:
    config = json.load(f)

# 移除 docker.io 从 noProxy
if 'proxies' in config and 'default' in config['proxies']:
    no_proxy = config['proxies']['default'].get('noProxy', '')
    no_proxy_list = [item.strip() for item in no_proxy.split(',') if item.strip()]
    no_proxy_list = [item for item in no_proxy_list if item not in ['docker.io', 'registry-1.docker.io']]
    config['proxies']['default']['noProxy'] = ','.join(no_proxy_list) if no_proxy_list else 'localhost,127.0.0.1'
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    print("✅ 配置已修复")
EOF
```

**重要：修复后必须重启 Docker Desktop！**

### 错误 2：代理连接失败

**错误信息：**
```
dial tcp 172.19.32.1:7890: connect: connection refused
```

**原因：**
- Windows 代理服务未运行
- 代理端口不正确
- Windows 防火墙阻止了连接

**解决方案：**
1. 确认 Windows 代理服务正在运行
2. 检查代理端口是否正确
3. 在代理客户端中启用"允许局域网连接"
4. 检查 Windows 防火墙设置

### 错误 3：IPv6 连接问题

**错误信息：**
```
dial tcp [2a03:2880:f10f:83:face:b00c:0:25de]:443: connectex: A connection attempt failed
```

**原因：**
- Docker 尝试使用 IPv6 连接，但网络不支持或配置有问题

**解决方案：**
1. 确保 Docker 通过代理访问（移除 `docker.io` 从 `noProxy`）
2. 或者配置 Docker 使用 IPv4：
   ```json
   {
     "proxies": {
       "default": {
         "httpProxy": "http://172.19.32.1:7890",
         "httpsProxy": "http://172.19.32.1:7890",
         "noProxy": "localhost,127.0.0.1"
       }
     },
     "ipv6": false
   }
   ```

## 诊断步骤

### 1. 检查 Docker 配置

```bash
cat ~/.docker/config.json
```

确认：
- `httpProxy` 和 `httpsProxy` 配置正确
- `noProxy` 中**不包含** `docker.io` 或 `registry-1.docker.io`

### 2. 测试代理连接

```bash
# 测试代理是否可用
curl -v --proxy http://172.19.32.1:7890 https://registry-1.docker.io/v2/
```

### 3. 检查 Docker 信息

```bash
docker info | grep -i proxy
```

### 4. 测试拉取镜像

```bash
# 测试拉取小镜像
docker pull hello-world

# 测试拉取目标镜像
docker pull pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime
```

### 5. 使用诊断脚本

```bash
bash scripts/diagnose_docker_connection.sh
```

## 完整修复流程

1. **修复配置文件**
   ```bash
   bash scripts/fix_docker_proxy_noProxy.sh
   ```

2. **重启 Docker Desktop**
   - 在 Windows 中右键点击 Docker 图标
   - 选择 "Quit Docker Desktop"
   - 重新打开 Docker Desktop

3. **验证修复**
   ```bash
   docker pull pytorch/pytorch:2.2.1-cuda12.1-cudnn8-runtime
   ```

4. **如果还有问题**
   ```bash
   bash scripts/diagnose_docker_connection.sh
   ```

## 预防措施

1. **使用正确的配置脚本**
   - 使用 `scripts/setup_docker_desktop_proxy.sh` 配置代理
   - 脚本已更新，不会在 `noProxy` 中包含 `docker.io`

2. **定期检查配置**
   - 如果手动编辑配置文件，确保 `noProxy` 中不包含 `docker.io`

3. **使用诊断工具**
   - 遇到问题时，先运行诊断脚本

## 相关文档

- [Docker Desktop 代理配置](docker_desktop_proxy_setup.md)
- [WSL 代理配置](wsl_proxy_setup.md)
- [Docker 安装指南](docker_installation_wsl2.md)
