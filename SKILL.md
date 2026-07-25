# Notion 工具集

当用户需要操作 Notion 但功能超出 notion-api MCP 范围时使用（字数统计、大文件上传、思维导图渲染等）。

## 触发条件

- 用户想算 Notion 页面字数
- 用户想往 Notion 传大文件（日志等）
- 用户想生成思维导图并嵌入 Notion
- 用户说"Notion 限制"、"代码块贴不进去"、"能不能算字数"

## 前置条件

NOTION_TOKEN 环境变量已配置。脚本在 `scripts/` 目录下，直接 exec 调用。

## 工具

### 1. 字数统计

```bash
bash scripts/wordcount.sh <page_id>
```

递归拉页面所有 block 的 rich_text，统计中文字符数、英文单词数、总字符数。

### 2. 大文件上传（待实现）

绕过 Notion 代码块 2000 字符限制，通过 API 上传文件块。

### 3. 思维导图渲染（待实现）

Mermaid 代码 → mermaid.ink 渲染 → 图片嵌入 Notion 页面。