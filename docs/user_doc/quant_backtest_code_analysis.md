# RD-Agent 量化回测代码逻辑分析

## 一、回测代码执行流程概览

当运行 `rdagent fin_quant` 后，回测部分的代码执行流程如下：

```
rdagent fin_quant
    ↓
QuantRDLoop.run()
    ↓
running() 方法
    ↓
QlibModelRunner.develop()
    ↓
QlibFBWorkspace.execute()
    ↓
qrun conf.yaml (Qlib 回测执行)
    ↓
python read_exp_res.py (结果提取)
```

## 二、核心代码位置

### 2.1 入口点

**文件**: `rdagent/app/cli.py`
```python
from rdagent.app.qlib_rd_loop.quant import main as fin_quant
app.command(name="fin_quant")(fin_quant)
```

**文件**: `rdagent/app/qlib_rd_loop/quant.py`
- `main()` 函数：创建 `QuantRDLoop` 并运行
- `QuantRDLoop.running()` 方法：根据动作类型（factor/model）调用相应的 runner

### 2.2 模型回测执行器

**文件**: `rdagent/scenarios/qlib/developer/model_runner.py`

**核心类**: `QlibModelRunner`

**关键方法**: `develop()`

主要逻辑：
1. 准备因子数据（如果有 SOTA 因子）
2. 注入模型代码到工作空间
3. 配置环境变量（训练/验证/测试时间段、超参数等）
4. 调用 `exp.experiment_workspace.execute()` 执行回测

**关键代码片段**：
```python
# 第 86-110 行
if exp.sub_tasks[0].model_type == "TimeSeries":
    if exist_sota_factor_exp:
        env_to_use.update(
            {"dataset_cls": "TSDatasetH", "num_features": num_features, "step_len": 20, "num_timesteps": 20}
        )
        result, stdout = exp.experiment_workspace.execute(
            qlib_config_name="conf_sota_factors_model.yaml", run_env=env_to_use
        )
    else:
        env_to_use.update({"dataset_cls": "TSDatasetH", "step_len": 20, "num_timesteps": 20})
        result, stdout = exp.experiment_workspace.execute(
            qlib_config_name="conf_baseline_factors_model.yaml", run_env=env_to_use
        )
elif exp.sub_tasks[0].model_type == "Tabular":
    # 类似逻辑...
```

### 2.3 回测工作空间执行

**文件**: `rdagent/scenarios/qlib/experiment/workspace.py`

**核心类**: `QlibFBWorkspace`

**关键方法**: `execute()`

**执行步骤**：
1. **准备环境**：根据配置选择 Docker 或 Conda 环境
2. **执行 Qlib 回测**：运行 `qrun {qlib_config_name}` 命令
3. **提取结果**：运行 `python read_exp_res.py` 提取回测结果
4. **返回结果**：返回回测指标和日志

**关键代码片段**：
```python
# 第 18-59 行
def execute(self, qlib_config_name: str = "conf.yaml", run_env: dict = {}, *args, **kwargs) -> str:
    # 1. 准备环境
    if MODEL_COSTEER_SETTINGS.env_type == "docker":
        qtde = QTDockerEnv()
    elif MODEL_COSTEER_SETTINGS.env_type == "conda":
        qtde = QlibCondaEnv(conf=QlibCondaConf())
    
    qtde.prepare()
    
    # 2. 执行 Qlib 回测
    execute_qlib_log = qtde.check_output(
        local_path=str(self.workspace_path),
        entry=f"qrun {qlib_config_name}",  # ← 这里是实际的回测执行
        env=run_env,
    )
    
    # 3. 提取结果
    execute_log = qtde.check_output(
        local_path=str(self.workspace_path),
        entry="python read_exp_res.py",  # ← 提取回测结果
        env=run_env,
    )
    
    # 4. 读取结果文件
    ret_df = pd.read_pickle(quantitative_backtesting_chart_path)
    qlib_res = pd.read_csv(qlib_res_path, index_col=0)
    
    return qlib_res, execute_qlib_log
```

### 2.4 Qlib 回测配置文件

**位置**: `rdagent/scenarios/qlib/experiment/model_template/`

**配置文件**：
- `conf_sota_factors_model.yaml`：使用 SOTA 因子库时的配置
- `conf_baseline_factors_model.yaml`：使用基线因子时的配置

**关键配置项**：

1. **数据配置** (`data_handler_config`):
   - `start_time`: 数据开始时间（默认 2008-01-01）
   - `end_time`: 数据结束时间
   - `instruments`: 股票池（默认 csi300）

2. **数据集划分** (`segments`):
   - `train`: 训练集时间段（默认 2008-01-01 至 2014-12-31）
   - `valid`: 验证集时间段（默认 2015-01-01 至 2016-12-31）
   - `test`: 测试集时间段（默认 2017-01-01 开始）

3. **回测配置** (`port_analysis_config`):
   - `strategy`: 交易策略（默认 TopkDropoutStrategy）
   - `backtest`: 回测参数
     - `start_time`: 回测开始时间（默认 2017-01-01）
     - `end_time`: 回测结束时间
     - `account`: 初始资金（默认 100000000）
     - `benchmark`: 基准指数（默认 SH000300）
     - `exchange_kwargs`: 交易成本配置
       - `open_cost`: 开仓成本（默认 0.0005）
       - `close_cost`: 平仓成本（默认 0.0015）
       - `min_cost`: 最小成本（默认 5）

4. **模型配置** (`task.model`):
   - `n_epochs`: 训练轮数
   - `lr`: 学习率
   - `batch_size`: 批次大小
   - `early_stop`: 早停轮数

### 2.5 结果提取脚本

**文件**: `rdagent/scenarios/qlib/experiment/model_template/read_exp_res.py`

**功能**：
1. 从 Qlib 的 MLflow 记录器中提取最新的实验结果
2. 提取回测指标（IC、收益、夏普比率等）
3. 保存为 CSV 文件（`qlib_res.csv`）
4. 保存回测图表数据（`ret.pkl`）

**关键代码**：
```python
# 获取最新的 recorder
latest_recorder = R.get_recorder(recorder_id=recorder_id, experiment_name=experiment)

# 提取指标
metrics = pd.Series(latest_recorder.list_metrics())
metrics.to_csv("qlib_res.csv")

# 提取回测结果
ret_data_frame = latest_recorder.load_object("portfolio_analysis/report_normal_1day.pkl")
ret_data_frame.to_pickle("ret.pkl")
```

## 三、可修改的部分

### 3.1 回测配置（推荐修改）

**位置**: `rdagent/scenarios/qlib/experiment/model_template/conf_*.yaml`

**可修改项**：

1. **时间段配置**：
   ```yaml
   segments:
     train: [{{ train_start }}, {{ train_end }}]
     valid: [{{ valid_start }}, {{ valid_end }}]
     test: [{{ test_start }}, {{ test_end }}]
   ```
   这些值可以通过环境变量传入（在 `QlibModelRunner.develop()` 中设置）

2. **回测策略**：
   ```yaml
   port_analysis_config:
     strategy:
       class: TopkDropoutStrategy  # ← 可以修改为其他策略
       kwargs:
         topk: 50  # ← 可以修改选股数量
         n_drop: 5  # ← 可以修改随机丢弃数量
   ```

3. **交易成本**：
   ```yaml
   exchange_kwargs:
     open_cost: 0.0005   # ← 可以修改开仓成本
     close_cost: 0.0015  # ← 可以修改平仓成本
     min_cost: 5         # ← 可以修改最小成本
   ```

4. **初始资金和基准**：
   ```yaml
   backtest:
     account: 100000000  # ← 可以修改初始资金
     benchmark: SH000300  # ← 可以修改基准指数
   ```

### 3.2 环境变量配置（推荐修改）

**位置**: `rdagent/scenarios/qlib/developer/model_runner.py`

**可修改项**：

在 `QlibModelRunner.develop()` 方法中（第 62-84 行），可以修改：

```python
env_to_use = {
    "train_start": mbps.train_start,      # ← 训练开始时间
    "train_end": mbps.train_end,          # ← 训练结束时间
    "valid_start": mbps.valid_start,      # ← 验证开始时间
    "valid_end": mbps.valid_end,          # ← 验证结束时间
    "test_start": mbps.test_start,        # ← 测试开始时间
    "n_epochs": "100",                     # ← 训练轮数
    "lr": "2e-4",                         # ← 学习率
    "batch_size": "256",                  # ← 批次大小
    # ...
}
```

这些值来自 `ModelBasePropSetting`，可以通过 `.env` 文件配置。

### 3.3 结果提取逻辑（可修改）

**位置**: `rdagent/scenarios/qlib/experiment/model_template/read_exp_res.py`

**可修改项**：

1. **提取的指标**：可以修改提取哪些指标
2. **结果文件格式**：可以修改保存格式（CSV、JSON 等）
3. **图表数据**：可以修改提取哪些图表数据

### 3.4 执行器逻辑（高级修改）

**位置**: `rdagent/scenarios/qlib/developer/model_runner.py`

**可修改项**：

1. **模型类型判断**：可以添加新的模型类型支持
2. **因子数据处理**：可以修改因子合并和去重逻辑
3. **环境变量设置**：可以添加新的环境变量

**位置**: `rdagent/scenarios/qlib/experiment/workspace.py`

**可修改项**：

1. **执行命令**：可以修改 `qrun` 命令的参数
2. **结果提取**：可以修改结果提取的逻辑
3. **错误处理**：可以增强错误处理和日志记录

## 四、修改建议

### 4.1 简单修改（推荐）

**修改回测配置**：
1. 直接编辑 `conf_sota_factors_model.yaml` 或 `conf_baseline_factors_model.yaml`
2. 修改时间段、策略参数、交易成本等
3. 重启运行即可生效

**修改环境变量**：
1. 在 `.env` 文件中设置 `MODEL_*` 相关配置
2. 例如：`MODEL_TRAIN_START=2009-01-01`

### 4.2 中等修改

**自定义结果提取**：
1. 修改 `read_exp_res.py`
2. 添加自定义指标提取逻辑
3. 修改结果保存格式

**自定义回测策略**：
1. 创建新的 Qlib 策略类
2. 在配置文件中引用新策略
3. 修改策略参数

### 4.3 高级修改

**修改执行器逻辑**：
1. 继承 `QlibModelRunner` 类
2. 重写 `develop()` 方法
3. 在配置中指定新的 runner 类

**修改工作空间执行**：
1. 继承 `QlibFBWorkspace` 类
2. 重写 `execute()` 方法
3. 添加自定义执行逻辑

## 五、配置文件详细说明

### 5.1 conf_sota_factors_model.yaml 结构

```yaml
qlib_init:          # Qlib 初始化配置
  provider_uri: "~/.qlib/qlib_data/cn_data"
  region: cn

market: &market csi300  # 股票池
benchmark: &benchmark SH000300  # 基准指数

data_handler_config:  # 数据处理器配置
  start_time: {{ train_start }}
  end_time: {{ test_end }}
  instruments: *market
  data_loader:  # 数据加载器
    - Alpha158DL  # 基础特征
    - StaticDataLoader  # 自定义因子（combined_factors_df.parquet）
  infer_processors:  # 推理时数据预处理
    - RobustZScoreNorm  # 标准化
    - Fillna  # 填充缺失值
  learn_processors:  # 训练时数据预处理
    - DropnaLabel
    - CSZScoreNorm

port_analysis_config:  # 组合分析配置
  strategy:  # 交易策略
    class: TopkDropoutStrategy
    kwargs:
      topk: 50
      n_drop: 5
  backtest:  # 回测配置
    start_time: {{ test_start }}
    end_time: {{ test_end }}
    account: 100000000
    benchmark: *benchmark
    exchange_kwargs:  # 交易成本
      open_cost: 0.0005
      close_cost: 0.0015

task:  # 任务配置
  model:  # 模型配置
    class: GeneralPTNN
    kwargs:
      n_epochs: {{ n_epochs }}
      lr: {{ lr }}
      # ...
  dataset:  # 数据集配置
    class: {{ dataset_cls }}
    kwargs:
      handler: *data_handler_config
      segments:  # 数据集划分
        train: [{{ train_start }}, {{ train_end }}]
        valid: [{{ valid_start }}, {{ valid_end }}]
        test: [{{ test_start }}, {{ test_end }}]
  record:  # 记录器配置
    - SignalRecord  # 信号记录
    - SigAnaRecord  # 信号分析记录
    - PortAnaRecord  # 组合分析记录
```

### 5.2 环境变量映射

配置文件中的 `{{ variable }}` 会被环境变量替换：

| 配置文件变量 | 环境变量 | 默认值 | 说明 |
|------------|---------|--------|------|
| `train_start` | `MODEL_TRAIN_START` | 2008-01-01 | 训练开始时间 |
| `train_end` | `MODEL_TRAIN_END` | 2014-12-31 | 训练结束时间 |
| `valid_start` | `MODEL_VALID_START` | 2015-01-01 | 验证开始时间 |
| `valid_end` | `MODEL_VALID_END` | 2016-12-31 | 验证结束时间 |
| `test_start` | `MODEL_TEST_START` | 2017-01-01 | 测试开始时间 |
| `test_end` | `MODEL_TEST_END` | null | 测试结束时间 |
| `n_epochs` | - | 100 | 训练轮数（从任务中获取） |
| `lr` | - | 2e-4 | 学习率（从任务中获取） |
| `batch_size` | - | 256 | 批次大小（从任务中获取） |

## 六、修改示例

### 示例 1：修改回测时间段

**方法 1：修改配置文件**
```yaml
# conf_sota_factors_model.yaml
port_analysis_config:
  backtest:
    start_time: 2018-01-01  # 修改回测开始时间
    end_time: 2020-12-31    # 修改回测结束时间
```

**方法 2：通过环境变量**
```bash
# .env 文件
MODEL_TEST_START=2018-01-01
MODEL_TEST_END=2020-12-31
```

### 示例 2：修改交易策略

```yaml
# conf_sota_factors_model.yaml
port_analysis_config:
  strategy:
    class: TopkDropoutStrategy
    kwargs:
      topk: 30        # 修改为选择 30 只股票
      n_drop: 3       # 修改为随机丢弃 3 只
```

### 示例 3：修改交易成本

```yaml
# conf_sota_factors_model.yaml
port_analysis_config:
  backtest:
    exchange_kwargs:
      open_cost: 0.001   # 修改开仓成本为 0.1%
      close_cost: 0.002  # 修改平仓成本为 0.2%
      min_cost: 10       # 修改最小成本为 10 元
```

### 示例 4：自定义结果提取

```python
# read_exp_res.py 中添加自定义指标
metrics = pd.Series(latest_recorder.list_metrics())

# 添加自定义计算
custom_metrics = {
    "custom_sharpe": calculate_custom_sharpe(ret_data_frame),
    "custom_max_drawdown": calculate_custom_max_drawdown(ret_data_frame),
}

metrics = pd.concat([metrics, pd.Series(custom_metrics)])
metrics.to_csv("qlib_res.csv")
```

## 七、注意事项

1. **配置文件模板语法**：配置文件使用 Jinja2 模板语法，`{{ variable }}` 会被环境变量替换
2. **缓存机制**：`QlibModelRunner` 使用了缓存机制，修改配置后可能需要清除缓存
3. **环境类型**：确保 `MODEL_COSTEER_SETTINGS.env_type` 配置正确（docker 或 conda）
4. **Qlib 版本**：确保 Qlib 版本兼容，某些配置可能需要特定版本的 Qlib
5. **数据路径**：确保 Qlib 数据路径正确（`~/.qlib/qlib_data/cn_data`）

## 八、调试建议

1. **查看日志**：检查 `Qlib_execute_log` 标签的日志，了解 Qlib 执行情况
2. **检查工作空间**：查看实验工作空间中的文件，确认配置是否正确注入
3. **测试配置**：可以单独运行 `qrun conf.yaml` 测试配置是否正确
4. **查看结果文件**：检查 `qlib_res.csv` 和 `ret.pkl` 文件，确认结果是否正确提取

---

**文档版本**：v1.0  
**最后更新**：基于代码深度分析生成
