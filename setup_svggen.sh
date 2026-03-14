#!/bin/bash
touch ~/.no_auto_tmux
cd /workspace/
set -e

ENV_NAME="svggen"
PYTHON_VERSION="3.11.3"

echo "=== Setting up environment for SVG Glyph Generation ==="

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
pip install --upgrade pip

# ---------------------------------------------------------------------------
# 3. Install PyTorch (CUDA 11.8 – matching system CUDA on Vast.ai)
#    See https://pytorch.org/get-started/locally/ for other variants.
# ---------------------------------------------------------------------------
echo ">>> Installing PyTorch (CUDA 11.8)"
uv pip install torch==2.5.1+cu118 torchvision==0.20.1+cu118 --index-url https://download.pytorch.org/whl/cu118

# ---------------------------------------------------------------------------
# 4. Install transformers from source (Qwen3-VL support requires >= 4.57.0)
# ---------------------------------------------------------------------------
echo ">>> Installing transformers from source"
uv pip install git+https://github.com/huggingface/transformers

# ---------------------------------------------------------------------------
# 5. Install Qwen3-VL
# ---------------------------------------------------------------------------
echo ">>> Installing Qwen3-VL and core ML packages"
uv pip install -U qwen-agent

# ---------------------------------------------------------------------------
# 6. Install vLLM (for training & inference)
# ---------------------------------------------------------------------------
echo ">>> Installing vLLM"
uv pip install -U vllm

# ---------------------------------------------------------------------------
# 7. Install  Other ML core package
# ---------------------------------------------------------------------------

uv pip install \
    accelerate \
    qwen-vl-utils==0.0.14 \
    pillow \
    requests \
    sentencepiece \
    protobuf==6.31.1

# ---------------------------------------------------------------------------
# 8. Install StarVector model 
# ---------------------------------------------------------------------------
cd ./star-vector
uv pip install meson-python meson ninja
apt-get update && apt-get install -y libcairo2-dev pkg-config
uv pip install flash-attn==2.7.3 --no-build-isolation
uv pip install -e . --no-build-isolation

cd ..

# ---------------------------------------------------------------------------
# 9. Quick sanity check
# ---------------------------------------------------------------------------
echo ""
echo ">>> Verifying installation..."
python - <<'PYEOF'
import torch, transformers, accelerate
print(f"  torch        : {torch.__version__}  (CUDA: {torch.cuda.is_available()})")
print(f"  transformers : {transformers.__version__}")
print(f"  accelerate   : {accelerate.__version__}")

try:
    import svgpathtools, cairosvg, lxml
    print(f"  svgpathtools : {svgpathtools.__version__}")
    print(f"  cairosvg     : {cairosvg.__version__}")
except ImportError as e:
    print(f"  WARNING: missing VecGlypher dep: {e}")

print()
print("Environment is ready. Example usage:")
print()
print('  from transformers import Qwen3VLForConditionalGeneration, AutoProcessor')
print()
print('  model = Qwen3VLForConditionalGeneration.from_pretrained(')
print('      "Qwen/Qwen3-VL-8B-Thinking",')
print('      torch_dtype=torch.bfloat16,')
print('      device_map="auto",')
print('  )')
print('  processor = AutoProcessor.from_pretrained("Qwen/Qwen3-VL-8B-Thinking")')
PYEOF

echo ""
echo "=== Done! Activate with: conda activate ${ENV_NAME} ==="
