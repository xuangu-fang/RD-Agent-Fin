# RD-Agent Data Science 配置指南

## 配置位置

### 1. 代码中的默认配置

主要配置类：`rdagent/app/data_science/conf.py` 中的 `DataScienceBasePropSetting`

**关键配置项：**

```python
class DataScienceBasePropSetting(KaggleBasePropSetting):
    model_config = SettingsConfigDict(env_prefix="DS_", protected_namespaces=())
```

这意味着所有配置都可以通过 `DS_` 前缀的环境变量覆盖。

### 2. 环境变量配置

可以通过以下方式设置：

1. **`.env` 文件**（推荐）
   ```bash
   dotenv set DS_MAX_TRACE_NUM 3
   ```

2. **系统环境变量**
   ```bash
   export DS_MAX_TRACE_NUM=3
   ```

3. **命令行参数**（部分配置支持）
   ```bash
   rdagent data_science --competition xxx --loop_n 5 --timeout 2h
   ```

## 主要配置项详解

### 🔄 循环和超时配置

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|---------|--------|------|
| `max_trace_num` | `DS_MAX_TRACE_NUM` | `1` | 最大并行 trace 数量 |
| `max_trace_hist` | `DS_MAX_TRACE_HIST` | `3` | trace 历史记录数量 |
| `coder_max_loop` | `DS_CODER_MAX_LOOP` | `10` | coder 最大循环次数 |
| `runner_max_loop` | `DS_RUNNER_MAX_LOOP` | `3` | runner 最大循环次数 |
| `debug_timeout` | `DS_DEBUG_TIMEOUT` | `600` | 调试数据运行超时（秒） |
| `debug_recommend_timeout` | `DS_DEBUG_RECOMMEND_TIMEOUT` | `600` | 调试数据推荐超时（秒） |
| `full_timeout` | `DS_FULL_TIMEOUT` | `3600` | 完整数据运行超时（秒） |
| `full_recommend_timeout` | `DS_FULL_RECOMMEND_TIMEOUT` | `3600` | 完整数据推荐超时（秒） |

### 📊 工作流配置

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|---------|--------|------|
| `consecutive_errors` | `DS_CONSECUTIVE_ERRORS` | `5` | 连续错误容忍次数 |
| `coding_fail_reanalyze_threshold` | `DS_CODING_FAIL_REANALYZE_THRESHOLD` | `3` | 编码失败后重新分析阈值 |
| `sample_data_by_LLM` | `DS_SAMPLE_DATA_BY_LLM` | `True` | 是否使用 LLM 采样数据 |

### 🎯 多 Trace 配置

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|---------|--------|------|
| `scheduler_temperature` | `DS_SCHEDULER_TEMPERATURE` | `1.0` | Trace 调度器温度参数 |
| `scheduler_c_puct` | `DS_SCHEDULER_C_PUCT` | `1.0` | MCTS 调度器探索常数 |
| `enable_score_reward` | `DS_ENABLE_SCORE_REWARD` | `False` | 启用基于分数的奖励 |
| `merge_hours` | `DS_MERGE_HOURS` | `0.0` | 最终合并时间（小时） |

### 🚀 超时扩展配置

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|---------|--------|------|
| `allow_longer_timeout` | `DS_ALLOW_LONGER_TIMEOUT` | `False` | 允许延长超时 |
| `coder_enable_llm_decide_longer_timeout` | `DS_CODER_ENABLE_LLM_DECIDE_LONGER_TIMEOUT` | `False` | Coder 允许 LLM 决定延长超时 |
| `runner_enable_llm_decide_longer_timeout` | `DS_RUNNER_ENABLE_LLM_DECIDE_LONGER_TIMEOUT` | `False` | Runner 允许 LLM 决定延长超时 |
| `coder_longer_timeout_multiplier_upper` | `DS_CODER_LONGER_TIMEOUT_MULTIPLIER_UPPER` | `3` | Coder 超时倍数上限 |
| `runner_longer_timeout_multiplier_upper` | `DS_RUNNER_LONGER_TIMEOUT_MULTIPLIER_UPPER` | `2` | Runner 超时倍数上限 |

## 命令行参数

`rdagent data_science` 支持以下命令行参数：

| 参数 | 说明 | 示例 |
|------|------|------|
| `--competition` | 竞赛名称（必需） | `--competition arf-12-hours-prediction-task` |
| `--loop_n` | 运行循环次数 | `--loop_n 5` |
| `--step_n` | 运行步骤次数 | `--step_n 10` |
| `--timeout` | 总超时时间 | `--timeout 2h` 或 `--timeout 3600` |
| `--checkout/--no-checkout` | 是否 checkout 会话 | `--checkout` |
| `--checkout_path` | checkout 路径 | `--checkout_path /path/to/log` |

## 配置示例

### 示例 1: 增加并行 trace 数量

```bash
# 在 .env 文件中设置
dotenv set DS_MAX_TRACE_NUM 3

# 或者使用环境变量
export DS_MAX_TRACE_NUM=3
```

### 示例 2: 调整超时时间

```bash
# 调试超时改为 30 分钟
dotenv set DS_DEBUG_TIMEOUT 1800

# 完整数据超时改为 2 小时
dotenv set DS_FULL_TIMEOUT 7200
```

### 示例 3: 启用超时自动延长

```bash
# 允许自动延长超时
dotenv set DS_ALLOW_LONGER_TIMEOUT True
dotenv set DS_CODER_ENABLE_LLM_DECIDE_LONGER_TIMEOUT True
dotenv set DS_RUNNER_ENABLE_LLM_DECIDE_LONGER_TIMEOUT True
```

### 示例 4: 使用命令行参数

```bash
# 运行 5 个循环，总超时 2 小时
rdagent data_science --competition arf-12-hours-prediction-task --loop_n 5 --timeout 2h
```

## 查看当前配置

### 方法 1: 查看环境变量

```bash
# 查看所有 DS_ 开头的环境变量
env | grep "^DS_"

# 或在 .env 文件中查看
grep "^DS_" .env
```

### 方法 2: Python 代码查看

```python
from rdagent.app.data_science.conf import DS_RD_SETTING

# 查看所有配置
print(DS_RD_SETTING.model_dump())

# 查看特定配置
print(f"Max trace num: {DS_RD_SETTING.max_trace_num}")
print(f"Debug timeout: {DS_RD_SETTING.debug_timeout}")
print(f"Full timeout: {DS_RD_SETTING.full_timeout}")
```

## 配置文件优先级

配置加载顺序（优先级从高到低）：

1. **命令行参数** - 最高优先级
2. **环境变量**（`DS_*`）
3. **`.env` 文件**（通过 `dotenv` 加载）
4. **代码默认值** - 最低优先级

## 常用配置模板

### 快速开发配置（短超时，快速迭代）

```bash
dotenv set DS_DEBUG_TIMEOUT 300      # 5 分钟
dotenv set DS_FULL_TIMEOUT 1800      # 30 分钟
dotenv set DS_MAX_TRACE_NUM 1         # 单 trace
dotenv set DS_CODER_MAX_LOOP 5        # 减少循环次数
```

### 生产配置（长超时，多 trace）

```bash
dotenv set DS_DEBUG_TIMEOUT 1800      # 30 分钟
dotenv set DS_FULL_TIMEOUT 7200      # 2 小时
dotenv set DS_MAX_TRACE_NUM 3         # 3 个并行 trace
dotenv set DS_CODER_MAX_LOOP 10       # 标准循环次数
dotenv set DS_ALLOW_LONGER_TIMEOUT True
```

### 调试配置（详细日志，单 trace）

```bash
dotenv set DS_MAX_TRACE_NUM 1
dotenv set DS_DEBUG_TIMEOUT 600
dotenv set DS_FULL_TIMEOUT 3600
dotenv set DS_CODER_MAX_LOOP 10
```

## 注意事项

1. **修改配置后需要重启**：如果正在运行，需要重新启动命令才能生效
2. **环境变量命名**：所有配置都需要 `DS_` 前缀
3. **布尔值**：使用 `True`/`False`（字符串）或 `1`/`0`
4. **超时单位**：代码中默认使用秒，命令行参数支持 `h`（小时）、`m`（分钟）等后缀

## 相关文件

- 配置定义：`rdagent/app/data_science/conf.py`
- 命令行入口：`rdagent/app/data_science/loop.py`
- 基础配置：`rdagent/app/kaggle/conf.py`

