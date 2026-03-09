#!/bin/bash
set -e

ENV_NAME="qwen3vl"
PYTHON_VERSION="3.11"

echo "=== Setting up environment for Qwen3-VL-8B-Thinking ==="

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
# 3. Install PyTorch (CUDA 12.6 – adjust the index-url for your CUDA version)
#    See https://pytorch.org/get-started/locally/ for other variants.
# ---------------------------------------------------------------------------
echo ">>> Installing PyTorch (CUDA 12.6)"
uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126

# ---------------------------------------------------------------------------
# 4. Install transformers from source (Qwen3-VL support requires >= 4.57.0)
# ---------------------------------------------------------------------------
echo ">>> Installing transformers from source"
uv pip install git+https://github.com/huggingface/transformers


# ---------------------------------------------------------------------------
# 5. Install remaining dependencies
# ---------------------------------------------------------------------------
echo ">>> Installing additional packages"
uv pip install \
    accelerate \
    qwen-vl-utils \
    pillow \
    requests \
    sentencepiece \
    protobuf

# ---------------------------------------------------------------------------
# 6. Quick sanity check
# ---------------------------------------------------------------------------
echo ""
echo ">>> Verifying installation..."
python - <<'PYEOF'
import torch, transformers, accelerate
print(f"  torch        : {torch.__version__}  (CUDA: {torch.cuda.is_available()})")
print(f"  transformers : {transformers.__version__}")
print(f"  accelerate   : {accelerate.__version__}")
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
