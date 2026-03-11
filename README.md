# SVG Agent

基于 Qwen-Agent 的多模态 SVG 设计助手，集成 VecGlypher 模型作为自定义 tool 实现矢量字形生成。

## 架构

```
用户请求 (图片 + 文本)
        |
        v
+-------------------+          +---------------------+
| 主 Agent (端口8000)|  tool调用  | VecGlypher (端口30000)|
| Qwen2.5-VL-7B    | -------> | VecGlypher-27b-it   |
| 理解图片、决策     |  <------- | 生成 SVG 字形        |
+-------------------+          +---------------------+
```

| 服务 | 端口 | 模型 | 显存需求 | 用途 |
|------|------|------|----------|------|
| 主 Agent | 8000 | Qwen/Qwen2.5-VL-7B-Instruct | ~16GB | 理解图片、决策、调用 tool |
| VecGlypher | 30000 | VecGlypher/VecGlypher-27b-it | ~54GB | 生成 SVG 字形 |

> 建议显存: 80GB+ (如 A100 80GB 或多卡)

## 环境准备

### 1. 安装依赖

```bash
pip install qwen-agent openai vllm
```

### 2. 初始化子模块

```bash
cd svg_agent
git submodule update --init --recursive
```

### 3. 下载模型

```bash
pip install -U huggingface_hub

# 主 Agent 模型
huggingface-cli download Qwen/Qwen2.5-VL-7B-Instruct \
    --local-dir saves/Qwen2.5-VL-7B-Instruct

# VecGlypher 微调模型 (27B, ~54GB 显存)
huggingface-cli download VecGlypher/VecGlypher-27b-it \
    --local-dir VecGlypher/saves/VecGlypher-27b-it
```

如果显存不足 (< 60GB)，可以下载基础模型自行微调:

```bash
# 小模型基座 (4B, ~10GB 显存)
huggingface-cli download Qwen/Qwen3-4B \
    --local-dir VecGlypher/saves/Qwen/Qwen3-4B
```

## 运行步骤

### Step 1: 启动主 Agent 模型 (终端 1)

```bash
vllm serve saves/Qwen2.5-VL-7B-Instruct --port 8000
```

等待出现 `Uvicorn running on http://0.0.0.0:8000` 后继续。

### Step 2: 启动 VecGlypher 模型 (终端 2)

```bash
vllm serve VecGlypher/saves/VecGlypher-27b-it --port 30000
```

等待出现 `Uvicorn running on http://0.0.0.0:30000` 后继续。

### Step 3: 运行 Agent (终端 3)

```bash
python svg_agent.py
```

## 配置说明

在 `svg_agent.py` 中可修改以下配置:

### 主 Agent 模型配置

```python
llm_cfg = {
    'model': 'Qwen/Qwen2.5-VL-7B-Instruct',  # 模型名 (与 vLLM 启动时一致)
    'model_type': 'qwenvl_oai',                # 多模态图片支持
    'model_server': 'http://localhost:8000/v1', # vLLM 服务地址
    'api_key': 'EMPTY',
}
```

### VecGlypher Tool 配置

在 `GenerateSVGGlyph.__init__` 中:
- `server_url`: VecGlypher vLLM 地址，默认 `http://localhost:30000/v1`
- `model_name`: 模型名，默认 `saves/Qwen3-4B`，改为你实际部署的模型路径

## 自定义 Tool 机制

本项目通过 Qwen-Agent 的 `@register_tool` 注册了 `generate_svg_glyph` 自定义 tool:

1. 主 Agent (Qwen2.5-VL) 接收用户的图片和文本请求
2. Agent 自主决定是否需要调用 `generate_svg_glyph` tool
3. Tool 内部通过 OpenAI 兼容 API 调用 VecGlypher 的 vLLM 服务
4. VecGlypher 返回 SVG path 数据，Agent 整合结果回复用户

参考: `Qwen-Agent/examples/function_calling.py`

## 项目结构

```
svg_agent/
├── svg_agent.py          # 主程序 (Agent + 自定义 Tool)
├── Qwen-Agent/           # Qwen-Agent 框架 (git submodule)
├── VecGlypher/           # VecGlypher 字形生成 (git submodule)
│   ├── saves/            # 模型权重存放目录
│   ├── src/serve/        # 推理服务代码
│   └── docs/             # 文档
├── qwen3vl.py            # Qwen3 VL 相关脚本
├── setup_qwen3vl.sh      # Qwen3 VL 环境配置
└── setup_svggen.sh       # SVG 生成环境配置
```
