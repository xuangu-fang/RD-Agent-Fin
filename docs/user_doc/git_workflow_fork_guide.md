# Git 工作流程指南：从直接 Clone 迁移到 Fork 模式

## 当前情况

您当前直接从 `microsoft/RD-Agent` clone 了仓库，没有 fork。这会导致：
- 无法直接推送代码到远程仓库
- 无法创建 Pull Request
- 工作流程不够灵活

## 推荐方案：创建 Fork 并迁移

### 方案 1：创建 Fork 并更新远程（推荐）

这是最标准的开源协作方式：

#### 步骤 1：在 GitHub 上创建 Fork

1. 访问 https://github.com/microsoft/RD-Agent
2. 点击右上角的 **Fork** 按钮
3. 选择您的 GitHub 账户
4. 等待 Fork 完成

#### 步骤 2：更新本地仓库的远程配置

```bash
# 查看当前远程配置
git remote -v

# 将 origin 重命名为 upstream（指向原始仓库）
git remote rename origin upstream

# 添加您的 fork 作为新的 origin
git remote add origin https://github.com/YOUR_USERNAME/RD-Agent.git

# 验证配置
git remote -v
```

现在您应该看到：
- `origin` -> 指向您的 fork
- `upstream` -> 指向原始仓库

#### 步骤 3：推送本地代码到您的 Fork

```bash
# 推送 main 分支到您的 fork
git push -u origin main

# 如果您的本地改动需要提交，先提交它们
# git add docs/user_doc/ scripts/
# git commit -m "Add local documentation and scripts"
# git push origin main
```

#### 步骤 4：设置分支跟踪

```bash
# 设置本地 main 跟踪您的 fork
git branch --set-upstream-to=origin/main main

# 设置 upstream 跟踪原始仓库（用于更新）
git remote set-branch --add --master upstream main
```

### 方案 2：保持现状，使用工作分支（简单方案）

如果您暂时不想创建 fork，可以这样工作：

#### 步骤 1：创建您的工作分支

```bash
# 创建一个新分支用于您的改动
git checkout -b my-local-changes

# 提交您的本地改动
git add docs/user_doc/ scripts/
git commit -m "Add local documentation and scripts for Docker setup"
```

#### 步骤 2：保持 main 分支与上游同步

```bash
# 切换到 main 分支
git checkout main

# 更新 main 分支
git pull origin main

# 需要时合并到您的工作分支
git checkout my-local-changes
git merge main
```

#### 步骤 3：如果需要推送，创建 fork 后再推送

当您需要推送代码时，再按照方案 1 创建 fork。

## 日常更新工作流程

### 如果使用 Fork 模式（方案 1）

```bash
# 1. 从原始仓库获取最新更新
git fetch upstream

# 2. 切换到 main 分支
git checkout main

# 3. 合并上游的更新
git merge upstream/main

# 4. 推送到您的 fork
git push origin main

# 5. 如果有工作分支，更新它
git checkout my-local-changes
git merge main
```

### 如果使用工作分支模式（方案 2）

```bash
# 1. 更新 main 分支
git checkout main
git pull origin main

# 2. 更新您的工作分支
git checkout my-local-changes
git merge main
```

## 创建 Pull Request

如果您使用 Fork 模式，可以这样创建 PR：

1. 在您的工作分支上提交改动
2. 推送到您的 fork：
   ```bash
   git push origin my-feature-branch
   ```
3. 在 GitHub 上：
   - 访问您的 fork: `https://github.com/YOUR_USERNAME/RD-Agent`
   - 点击 "Compare & pull request"
   - 选择 base: `microsoft/RD-Agent:main` <- compare: `YOUR_USERNAME/RD-Agent:my-feature-branch`
   - 填写 PR 描述并提交

## 当前本地文件的处理

您当前有未跟踪的文件：
- `docs/user_doc/` - 文档文件
- `scripts/` - 脚本文件

### 选项 1：保留为本地文件（不提交）

如果这些是您的个人配置或本地工具，可以：
- 将它们添加到 `.gitignore`
- 或者保持未跟踪状态

### 选项 2：提交到您的 fork

如果这些改动对项目有价值，可以：

```bash
# 创建功能分支
git checkout -b feature/docker-setup-guides

# 添加文件
git add docs/user_doc/ scripts/

# 提交
git commit -m "Add Docker setup guides and diagnostic scripts for WSL2"

# 推送到您的 fork
git push origin feature/docker-setup-guides

# 然后创建 Pull Request
```

## 快速设置脚本

如果您选择方案 1（Fork 模式），可以使用以下脚本快速设置：

```bash
#!/bin/bash
# 设置 Fork 工作流程

# 替换为您的 GitHub 用户名
GITHUB_USERNAME="YOUR_USERNAME"

# 重命名 origin 为 upstream
git remote rename origin upstream 2>/dev/null || echo "Origin already renamed or doesn't exist"

# 添加您的 fork 作为 origin
git remote add origin "https://github.com/${GITHUB_USERNAME}/RD-Agent.git" 2>/dev/null || echo "Origin already exists"

# 验证
echo "当前远程配置："
git remote -v

echo ""
echo "下一步："
echo "1. 确保您已经在 GitHub 上创建了 Fork"
echo "2. 运行: git push -u origin main"
```

## 建议

1. **立即创建 Fork**：即使现在不需要推送代码，创建 fork 也是免费的，可以随时使用
2. **使用功能分支**：不要直接在 main 分支上工作，创建功能分支
3. **定期同步**：定期从 upstream 拉取更新，保持代码同步
4. **提交本地改动**：如果您的文档和脚本对项目有价值，考虑提交 PR

## 常见问题

### Q: 我已经直接 clone 了，创建 fork 会丢失我的改动吗？

A: 不会。您的本地改动都在本地仓库中。创建 fork 只是添加一个新的远程仓库，不会影响本地文件。

### Q: 我可以同时使用 upstream 和 origin 吗？

A: 可以。这是推荐的做法：
- `upstream` -> 原始仓库（用于获取更新）
- `origin` -> 您的 fork（用于推送代码）

### Q: 如果我不想创建 fork，还有其他方式吗？

A: 可以保持现状，但您将无法：
- 直接推送代码到远程
- 创建 Pull Request
- 在多个设备间同步您的改动

### Q: 如何撤销远程配置的更改？

A: 如果需要恢复：
```bash
# 删除添加的远程
git remote remove origin

# 恢复原来的名称
git remote rename upstream origin
```
