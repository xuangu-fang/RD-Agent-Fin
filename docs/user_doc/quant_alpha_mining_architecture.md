# RD-Agent 量化 Alpha 挖掘核心架构分析

## 概述

RD-Agent(Q) 是首个数据驱动的量化多智能体框架，通过协调因子-模型协同优化来自动化量化策略的全栈研发。本文档基于 `docs/scens/quant_agent_fin.rst`，深入分析 RD-Agent 用于量化 Alpha 挖掘的核心组件和设计架构。

## 一、整体架构设计

### 1.1 核心设计理念

RD-Agent(Q) 采用**双路径协同优化**的设计理念：

- **因子挖掘路径（Factor Path）**：自动发现和实现量化因子
- **模型训练路径（Model Path）**：基于因子库训练预测模型
- **协同优化机制**：通过智能动作选择（Bandit/LLM）动态决定优先优化因子还是模型

### 1.2 主循环架构

系统核心是 `QuantRDLoop` 类，它继承自 `RDLoop`，实现了完整的研发循环：

```python
# 核心工作流程
Propose (假设生成) 
  ↓
Experiment Generation (实验生成)
  ↓
Coding (代码实现)
  ↓
Running (执行运行)
  ↓
Feedback (反馈评估)
  ↓
[循环回到 Propose]
```

## 二、核心组件详解

### 2.1 假设生成器（Hypothesis Generator）

**组件位置**：`rdagent/scenarios/qlib/proposal/quant_proposal.py`

**核心类**：`QlibQuantHypothesisGen`

**功能职责**：
1. **动作选择**：决定本次迭代是挖掘因子（factor）还是训练模型（model）
   - **Bandit 算法**：基于历史实验的指标（如 IC、收益等）进行多臂老虎机选择
   - **LLM 选择**：使用大语言模型分析历史反馈，智能决策
   - **随机选择**：用于对比实验

2. **上下文准备**：
   - 收集历史假设和反馈信息
   - 根据选择的动作（factor/model）筛选相关历史记录
   - 准备 RAG（检索增强生成）提示，引导生成方向

3. **假设生成**：
   - 对于因子：生成 1-5 个因子假设，包含因子名称、描述、数学公式
   - 对于模型：生成模型架构假设，包含网络结构、超参数等

**关键设计点**：
- 使用 `QuantTrace` 维护实验历史，包含 Bandit 控制器
- 根据实验阶段（前 6 轮 vs 后续）调整 RAG 策略
- 支持从 SOTA 因子库中检索，避免重复实现

### 2.2 实验生成器（Hypothesis2Experiment）

**因子实验生成**：`QlibFactorHypothesis2Experiment`
- 将因子假设转换为 `FactorTask` 对象
- 每个因子任务包含：因子名称、描述、数学公式、变量定义

**模型实验生成**：`QlibModelHypothesis2Experiment`
- 将模型假设转换为 `ModelTask` 对象
- 包含模型类型、网络结构、训练超参数等

### 2.3 代码生成器（Coder）

#### 2.3.1 因子代码生成器（FactorCoSTEER）

**组件位置**：`rdagent/components/coder/factor_coder/__init__.py`

**核心类**：`FactorCoSTEER`（继承自 `CoSTEER`）

**CoSTEER 框架**：
CoSTEER（Code Synthesis Through Evolution, Evaluation, and Retrieval）是 RD-Agent 的核心代码生成框架，采用进化式代码生成策略：

1. **知识检索（RAG）**：
   - 从知识库中检索相似的成功实现案例
   - 检索失败的案例，避免重复错误
   - 支持 V1 和 V2 两种检索策略

2. **多轮进化**：
   - 基于评估反馈迭代改进代码
   - 每次进化都会生成新的实现版本
   - 最多进行 `max_loop` 轮（默认 10 轮）

3. **评估机制**：
   - 使用 `FactorEvaluatorForCoder` 进行多维度评估
   - 包含执行反馈、代码质量、因子值验证等

**因子评估器（FactorEvaluatorForCoder）**：

评估流程分为三个层次：

1. **执行反馈（Execution Feedback）**：
   - 运行因子代码，检查是否有语法错误、运行时错误
   - 验证是否能成功生成因子值 DataFrame

2. **因子值评估（Value Evaluation）**：
   - 检查生成的因子值是否符合预期格式
   - 验证因子值的统计特性（如分布、缺失值等）
   - 与已有因子进行相关性检查，避免重复

3. **代码质量评估（Code Evaluation）**：
   - 分析代码逻辑是否正确
   - 检查是否遵循最佳实践
   - 评估代码可读性和可维护性

4. **最终决策（Final Decision）**：
   - 综合所有评估结果，决定是否接受该实现
   - 如果因子值与已有因子高度相关，直接拒绝

**因子任务（FactorTask）**：
- 定义因子实现的具体要求
- 包含因子名称、描述、数学公式、所需变量
- 支持版本管理，兼容不同实现版本

#### 2.3.2 模型代码生成器（ModelCoSTEER）

**组件位置**：`rdagent/components/coder/model_coder/__init__.py`

**核心类**：`ModelCoSTEER`（继承自 `CoSTEER`）

**功能特点**：
- 生成 PyTorch 神经网络模型代码
- 支持多种模型类型：LSTM、GRU、Transformer 等
- 自动生成模型结构定义和初始化代码

**模型评估器（ModelCoSTEEREvaluator）**：
评估维度包括：
1. **形状检查（Shape Evaluation）**：验证模型输入输出维度
2. **值检查（Value Evaluation）**：使用固定输入测试模型输出
3. **代码质量（Code Evaluation）**：检查代码正确性
4. **最终评估（Final Evaluation）**：综合判断模型是否可用

### 2.4 执行器（Runner）

#### 2.4.1 因子执行器（FactorRunner）

**组件位置**：`rdagent/scenarios/qlib/developer/factor_runner.py`

**核心类**：`QlibFactorRunner`

**功能流程**：

1. **因子数据处理**：
   - 从各个因子工作空间中提取生成的因子值
   - 合并为统一的 DataFrame 格式
   - 处理时间序列对齐、缺失值填充等

2. **去重机制**：
   - 计算新因子与 SOTA 因子库的 IC（信息系数）相关性
   - 如果相关性 > 0.99，认为因子重复，自动过滤
   - 确保因子库的多样性和有效性

3. **因子库更新**：
   - 将新因子与 SOTA 因子合并
   - 保存为 parquet 格式，供模型训练使用
   - 维护因子库的版本历史

4. **缓存机制**：
   - 使用 `cache_with_pickle` 避免重复计算
   - 基于因子内容生成缓存键

#### 2.4.2 模型执行器（ModelRunner）

**组件位置**：`rdagent/scenarios/qlib/developer/model_runner.py`

**核心类**：`QlibModelRunner`

**功能流程**：

1. **因子数据准备**：
   - 加载 SOTA 因子库（来自因子执行器的输出）
   - 将因子数据格式化为 Qlib 所需的格式
   - 保存为 `combined_factors_df.parquet`

2. **模型代码注入**：
   - 将生成的模型代码注入到实验工作空间
   - 替换模板中的 `model.py` 文件

3. **Qlib 回测执行**：
   - 使用 Qlib 框架执行模型训练和回测
   - 配置训练/验证/测试数据集划分
   - 执行超参数优化（如果指定）

4. **结果提取**：
   - 从 Qlib 输出中提取回测结果
   - 计算关键指标：收益率、夏普比率、最大回撤等
   - 保存为结构化数据供反馈生成使用

### 2.5 反馈生成器（Summarizer）

#### 2.5.1 因子反馈生成器（FactorExperiment2Feedback）

**功能**：
- 分析因子执行结果
- 提取关键指标：IC、ICIR、因子覆盖率等
- 生成结构化的反馈信息，指导下一轮假设生成

#### 2.5.2 模型反馈生成器（ModelExperiment2Feedback）

**功能**：
- 分析模型回测结果
- 提取关键指标：年化收益、夏普比率、最大回撤、信息比率等
- 对比基准模型（如 CSI300）的表现
- 生成改进建议

## 三、工作流程详解

### 3.1 完整迭代流程

```
┌─────────────────────────────────────────────────────────────┐
│                    QuantRDLoop 主循环                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │  1. Propose (假设生成)            │
        │     - QlibQuantHypothesisGen      │
        │     - 动作选择：factor 或 model   │
        │     - 生成假设和理由              │
        └───────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │  2. Experiment Generation         │
        │     - Factor/Model                │
        │       Hypothesis2Experiment       │
        │     - 转换为 Task 对象            │
        └───────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │  3. Coding (代码生成)              │
        │     - FactorCoSTEER /             │
        │       ModelCoSTEER                │
        │     - CoSTEER 多轮进化            │
        │     - RAG 知识检索                │
        │     - 多维度评估                  │
        └───────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │  4. Running (执行)                │
        │     - FactorRunner:               │
        │       * 提取因子值                │
        │       * 去重合并                  │
        │     - ModelRunner:                │
        │       * Qlib 回测                 │
        │       * 结果提取                  │
        └───────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────┐
        │  5. Feedback (反馈生成)            │
        │     - Factor/Model                │
        │       Experiment2Feedback         │
        │     - 指标提取和分析              │
        │     - 更新 Trace 历史             │
        └───────────────────────────────────┘
                            │
                            ▼
                    [循环回到 Propose]
```

### 3.2 因子挖掘详细流程

```
因子假设生成
    ↓
FactorTask 创建（包含因子描述、公式、变量）
    ↓
FactorCoSTEER.develop()
    ├─ RAG 知识检索
    │   ├─ 检索成功案例
    │   └─ 检索失败案例（避免重复错误）
    ├─ 多轮进化循环（最多 max_loop 轮）
    │   ├─ 生成/改进代码
    │   ├─ FactorEvaluatorForCoder 评估
    │   │   ├─ 执行反馈
    │   │   ├─ 因子值评估
    │   │   ├─ 代码质量评估
    │   │   └─ 最终决策
    │   └─ 基于反馈改进
    └─ 返回最佳实现
    ↓
FactorRunner.develop()
    ├─ 提取因子值 DataFrame
    ├─ 与 SOTA 因子库去重（IC 相关性检查）
    ├─ 合并因子库
    └─ 保存为 parquet 文件
    ↓
FactorExperiment2Feedback.generate_feedback()
    ├─ 计算 IC、ICIR 等指标
    └─ 生成反馈信息
```

### 3.3 模型训练详细流程

```
模型假设生成
    ↓
ModelTask 创建（包含模型类型、结构、超参数）
    ↓
ModelCoSTEER.develop()
    ├─ RAG 知识检索
    ├─ 多轮进化循环
    │   ├─ 生成/改进模型代码
    │   ├─ ModelCoSTEEREvaluator 评估
    │   │   ├─ 形状检查
    │   │   ├─ 值检查
    │   │   ├─ 代码质量
    │   │   └─ 最终评估
    │   └─ 基于反馈改进
    └─ 返回最佳实现
    ↓
ModelRunner.develop()
    ├─ 加载 SOTA 因子库
    ├─ 注入模型代码到工作空间
    ├─ 配置 Qlib 回测参数
    ├─ 执行训练和回测
    └─ 提取回测结果
    ↓
ModelExperiment2Feedback.generate_feedback()
    ├─ 计算收益、夏普比率等指标
    └─ 生成反馈信息
```

## 四、关键技术特性

### 4.1 CoSTEER 进化式代码生成

**核心优势**：
1. **知识复用**：通过 RAG 检索历史成功案例，避免重复实现
2. **错误学习**：记录失败案例，避免重复错误
3. **迭代改进**：基于多维度反馈持续优化代码
4. **自适应停止**：当达到可接受质量时提前停止

**进化策略**：
- 使用 `FactorMultiProcessEvolvingStrategy` 支持并行进化
- 每次进化都会尝试改进代码的不同方面
- 保留最佳实现作为 fallback

### 4.2 智能动作选择

**Bandit 算法**：
- 基于历史实验的指标（如 IC、收益）进行多臂老虎机选择
- 自动平衡探索（exploration）和利用（exploitation）
- 当因子挖掘效果不佳时，自动转向模型优化

**LLM 选择**：
- 使用大语言模型分析历史反馈
- 理解实验上下文，做出更智能的决策
- 可以处理更复杂的策略选择逻辑

### 4.3 因子-模型协同优化

**协同机制**：
1. **因子库积累**：每次成功的因子挖掘都会加入因子库
2. **模型复用因子**：模型训练自动使用最新的因子库
3. **反馈循环**：模型性能反馈指导因子挖掘方向
4. **去重机制**：确保因子库的多样性和有效性

**数据流**：
```
因子挖掘 → 因子库更新 → 模型训练使用因子库 → 模型性能反馈 → 指导下一轮因子挖掘
```

### 4.4 缓存和性能优化

**缓存策略**：
- 因子执行结果缓存：基于因子内容哈希
- 模型回测结果缓存：基于配置和代码哈希
- 避免重复计算，提高效率

**并行处理**：
- 支持多个实验并行执行
- 使用 `max_parallel` 控制并发数
- 异步执行提高吞吐量

## 五、配置和扩展

### 5.1 环境配置

**关键配置项**（通过 `.env` 文件或环境变量）：

- `QLIB_QUANT_*`：量化主循环配置
  - `action_selection`：动作选择策略（bandit/llm/random）
  - `evolving_n`：进化轮数

- `FACTOR_CoSTEER_*`：因子代码生成配置
  - `max_loop`：最大进化轮数
  - `data_folder`：因子数据文件夹
  - `file_based_execution_timeout`：执行超时时间

- `CoSTEER_*`：CoSTEER 框架配置
  - `knowledge_base_path`：知识库路径
  - `new_knowledge_base_path`：新知识库保存路径

### 5.2 Qlib 配置

**模型模板配置**（`model_template/conf.yaml`）：
- 数据范围：2008-01-01 至 2022-08-01
- 数据集划分：训练（2008-2014）、验证（2015-2016）、测试（2017-2020）
- 模型类型：GeneralPTNN（PyTorch 神经网络）
- 回测策略：TopkDropoutStrategy（选择 top 50 股票，随机丢弃 5 个）

**因子模板配置**（`factor_template/conf.yaml`）：
- 使用 Alpha158DL 生成基础特征
- 加载预计算的因子文件（`combined_factors_df.parquet`）
- 数据标准化和缺失值处理

### 5.3 扩展点

**自定义因子评估器**：
- 继承 `FactorEvaluatorForCoder`
- 实现自定义的评估逻辑

**自定义模型评估器**：
- 继承 `ModelCoSTEEREvaluator`
- 添加领域特定的评估维度

**自定义动作选择策略**：
- 实现新的选择算法
- 在 `QlibQuantHypothesisGen` 中集成

## 六、设计亮点总结

### 6.1 数据驱动

- 所有决策基于实际执行结果和指标
- 因子去重基于 IC 相关性，而非简单的代码相似性
- 模型评估基于真实回测结果

### 6.2 自动化程度高

- 从假设生成到代码实现、执行、评估全流程自动化
- 无需人工干预即可持续优化

### 6.3 知识积累

- 通过 RAG 机制积累成功案例
- 记录失败案例，避免重复错误
- 知识库持续增长，系统能力不断提升

### 6.4 协同优化

- 因子和模型相互促进
- 因子库为模型提供特征
- 模型性能反馈指导因子挖掘方向

### 6.5 鲁棒性

- 多维度评估确保代码质量
- 错误处理和异常恢复机制
- 缓存机制提高效率和稳定性

## 七、使用建议

### 7.1 初始设置

1. **准备数据**：确保 Qlib 数据已下载（`~/.qlib/qlib_data/cn_data`）
2. **配置环境**：设置必要的环境变量
3. **选择策略**：根据需求选择动作选择策略（推荐使用 bandit）

### 7.2 运行监控

- 关注因子库的增长和质量
- 监控模型回测指标的变化趋势
- 分析反馈信息，理解系统决策逻辑

### 7.3 调优建议

- **因子挖掘**：如果因子质量不佳，可以调整 RAG 提示或增加进化轮数
- **模型训练**：如果模型性能不佳，可以调整超参数或尝试不同的模型架构
- **动作选择**：根据实际情况调整 Bandit 参数或切换到 LLM 选择

## 八、参考文献

- RD-Agent(Q) 论文：https://arxiv.org/abs/2505.15155
- Qlib 文档：https://qlib.readthedocs.io/
- 源代码位置：`rdagent/app/qlib_rd_loop/quant.py`

---

**文档版本**：v1.0  
**最后更新**：基于 `docs/scens/quant_agent_fin.rst` 分析生成

