import json
import torch
from PIL import Image
from transformers import Qwen3VLForConditionalGeneration, AutoProcessor, AutoModelForCausalLM
from starvector.data.util import process_and_rasterize_svg
from qwen_agent.llm import get_chat_model

# ── StarVector model (lazy‑loaded singleton) ──────────────────────────
_starvector = None

def _load_main_model(model_name: str = "Qwen/Qwen3-VL-8B-Thinking"):
    main_model = Qwen3VLForConditionalGeneration.from_pretrained(
    "Qwen/Qwen3-VL-8B-Thinking", dtype="auto", device_map="auto"
)
    
    
def _load_model(model_name: str = "starvector/starvector-8b-im2svg"):
    global _starvector
    if _starvector is None:
        _starvector = AutoModelForCausalLM.from_pretrained(
            model_name, torch_dtype=torch.float16, trust_remote_code=True
        )
        _starvector.cuda()
        _starvector.eval()
    return _starvector


# ── Tool function ─────────────────────────────────────────────────────
def generate_svg(image_path: str, max_length: int = 4000):
    """Generate SVG code from an input image using StarVector.

    Args:
        image_path: Path to the input image file (png, jpg, etc.).
        max_length: Maximum token length for SVG generation. Defaults to 4000.

    Returns:
        A dict containing the generated SVG code and the rasterized preview path.
    """
    model = _load_model()
    processor = model.model.processor
    tokenizer = model.model.svg_transformer.tokenizer

    image_pil = Image.open(image_path).convert("RGB")
    image = processor(image_pil, return_tensors="pt")["pixel_values"].cuda()
    if not image.shape[0] == 1:
        image = image.squeeze(0)

    raw_svg = model.generate_im2svg({"image": image}, max_length=max_length)[0]
    svg_code, raster_image = process_and_rasterize_svg(raw_svg)

    return {
        "svg_code": svg_code,
        "status": "success",
    }


def get_function_by_name(name):
    if name == "generate_svg":
        return generate_svg


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "generate_svg",
            "description": "Generate SVG vector graphics code from an input raster image using StarVector. Suitable for icons, logos, diagrams, fonts, and emoji.",
            "parameters": {
                "type": "object",
                "properties": {
                    "image_path": {
                        "type": "string",
                        "description": "Path to the input image file (png, jpg, etc.).",
                    },
                    "max_length": {
                        "type": "integer",
                        "description": "Maximum token length for SVG generation. Defaults to 4000.",
                    },
                },
                "required": ["image_path"],
            },
        },
    },
]

MESSAGES = [
    {"role": "user", "content": "Please convert the image at 'assets/examples/sample-18.png' into SVG."},
]

def main():
    main_model = _load_main_model()
    svg_model = _load_model()
    response = svg_model.chat(MESSAGES, tools=TOOLS, get_function_by_name=get_function_by_name)
    print(json.dumps(response, indent=2))
