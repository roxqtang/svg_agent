#!/bin/bash
set -e

ENV_NAME="svggen"
PYTHON_VERSION="3.11.3"

echo "=== Setting up environment for SVG Glyph Generation ==="

# ---------------------------------------------------------------------------
# 0. Fix libstdc++ for CXXABI_1.3.15 (needed by vLLM / sqlite3)
# ---------------------------------------------------------------------------
export LD_LIBRARY_PATH=/opt/miniforge3/lib:${LD_LIBRARY_PATH:-}

# ---------------------------------------------------------------------------
# 1. Install uv if not already available
# ---------------------------------------------------------------------------
if ! command -v uv &>/dev/null; then
    echo ">>> Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# ---------------------------------------------------------------------------
# 2. Create and activate a conda environment
# ---------------------------------------------------------------------------
echo ">>> Creating conda environment '${ENV_NAME}' with Python ${PYTHON_VERSION}"
conda create -y -n "${ENV_NAME}" python="${PYTHON_VERSION}"
eval "$(conda shell.bash hook)"
conda activate "${ENV_NAME}"

# ---------------------------------------------------------------------------
# 3. Install vLLM and dependencies
# ---------------------------------------------------------------------------
echo ">>> Installing vLLM and dependencies"
uv pip install -U vllm
uv pip install qwen-vl-utils==0.0.14
uv pip install -U "qwen-agent[gui,rag,code_interpreter,mcp]"

echo "=== Setup complete ==="
echo "To start vLLM server, run:"
echo "vllm serve Qwen/Qwen3-VL-8B-Thinking --async-scheduling --host 0.0.0.0 --port 8000 --max-model-len 8000"

