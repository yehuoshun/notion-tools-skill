# notion-tools-skill

OpenClaw Skill，补足 Notion API 缺失的功能。

## 工具

| 脚本 | 功能 | 状态 |
|------|------|------|
| `scripts/wordcount.sh` | 页面字数统计 | ✅ 已实现 |
| 大文件上传 | 绕过代码块限制 | 📝 待实现 |
| 思维导图渲染 | Mermaid → 图片嵌入 | 📝 待实现 |

## 用法

```bash
# 需要 NOTION_TOKEN 环境变量
bash scripts/wordcount.sh <page_id>
```