# Copyright 2023 The Qwen team, Alibaba Group. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""An agent implemented by assistant with qwenvl, with VecGlypher as a custom tool."""

import json

from openai import OpenAI
from qwen_agent.agents import FnCallAgent
from qwen_agent.tools.base import BaseTool, register_tool


# ============================================================
# 自定义 Tool：调用 VecGlypher 模型生成 SVG 字形
# ============================================================
VECGLYPHER_SYSTEM_PROMPT = """You are a specialized vector glyph designer creating SVG path elements.

CRITICAL REQUIREMENTS:
- Each glyph must be a complete, self-contained <path> element, in reading order of the given text.
- Terminate each <path> element with a newline character
- Output ONLY valid SVG <path> elements"""


@register_tool('generate_svg_glyph')
class GenerateSVGGlyph(BaseTool):
    description = (
        'Generate vector SVG glyph/font for given characters with specified style. '
        'Input style description and text content, returns SVG path data.'
    )
    parameters = [
        {
            'name': 'text',
            'type': 'string',
            'description': 'The characters to generate glyphs for, e.g. "a" or "hello"',
            'required': True,
        },
        {
            'name': 'style',
            'type': 'string',
            'description': (
                'Font style description, e.g. '
                '"humanist sans-serif, 600 weight, calm, competent, normal style"'
            ),
            'required': False,
        },
    ]

    def __init__(self, cfg=None):
        super().__init__(cfg)
        # VecGlypher vLLM 服务配置（默认端口 30000）
        self.server_url = (cfg or {}).get('server_url', 'http://localhost:30000/v1')
        self.model_name = (cfg or {}).get('model_name', 'saves/Qwen3-4B')
        self.client = OpenAI(base_url=self.server_url, api_key='EMPTY')

    def call(self, params: str, **kwargs) -> str:
        params = json.loads(params)
        text = params['text']
        style = params.get('style', '')

        # 构造 VecGlypher 的 prompt
        # 多个字符用 <|SEP|> 分隔
        if len(text) > 1:
            text_content = '<|SEP|>'.join(text)
        else:
            text_content = text

        user_prompt = ''
        if style:
            user_prompt += f'Font design requirements: {style}\n'
        user_prompt += f'Text content: {text_content}'

        # 调用 VecGlypher vLLM 服务
        resp = self.client.chat.completions.create(
            model=self.model_name,
            messages=[
                {'role': 'system', 'content': VECGLYPHER_SYSTEM_PROMPT},
                {'role': 'user', 'content': user_prompt},
            ],
            temperature=0.7,
            top_p=0.8,
            max_tokens=8192,
            extra_body={'chat_template_kwargs': {'enable_thinking': False}},
        )

        svg_content = resp.choices[0].message.content
        return json.dumps({'svg_paths': svg_content}, ensure_ascii=False)


# ============================================================
# Agent 配置
# ============================================================
def init_agent_service():
    llm_cfg = {
        'model': 'Qwen/Qwen2.5-VL-7B-Instruct',  # 主 Agent 模型（部署在 8000 端口）
        'model_type': 'qwenvl_oai',  # 关键：使用支持多模态（图片）的 OAI 客户端
        'model_server': 'http://localhost:8000/v1',
        'api_key': 'EMPTY',
    }

    tools = [
        'generate_svg_glyph',   # 自定义的 VecGlypher tool
        'image_zoom_in_tool',
        'image_search',
        'web_search',
    ]
    bot = FnCallAgent(
        llm=llm_cfg,
        function_list=tools,
        name='SVG Agent',
        system_message='You are an SVG design assistant. You can generate vector font glyphs using the generate_svg_glyph tool.',
    )

    return bot


def test(pic_url: str, query: str):
    bot = init_agent_service()

    messages = [{
        'role': 'user',
        'content': [
            {
                'image': pic_url
            },
            {
                'text': query
            },
        ]
    }]

    response = list(bot.run(messages=messages))[-1]
    print(response)

    response_plain_text = response[-1]['content']
    print('\n\nFinal Response:\n', response_plain_text)


if __name__ == '__main__':
    test('https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20241022/emyrja/dog_and_girl.jpeg',
         '告诉我这只狗的品种，并且输出"狗"这个字的 SVG 字形，要求字体风格是 humanist sans-serif, 600 weight, calm, competent, normal style')
