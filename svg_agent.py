from transformers import Qwen3VLForConditionalGeneration, AutoProcessor

class SVGAgent:
    def __init__(self, model_name ='Qwen/Qwen3-VL-8B-Thinking'):
        self.model_name = model_name
        self.model = None
        self.preprocessor = None

    def initialize_model(self,):
        if self.model is None:
            self.model = Qwen3VLForConditionalGeneration.from_pretrained(
                self.model_name, dtype="auto", device_map="auto"
            )
        if self.preprocessor is None:
            self.processor = AutoProcessor.from_pretrained(self.model_name)


if __name__ == "__main__":
    agent = SVGAgent()
    agent.initialize_model()