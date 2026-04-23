# xiaozhi-creator-skill

将小智 API 的 6 个核心能力封装为可安装 skill：创建智能体、更新智能体、模型列表、智能体列表、设备列表、添加设备。

## 安装

```bash
npx skills add Pesifar/xiaozhi-creator-skill
```

例如（示例）：

```bash
npx skills add Pesifar/xiaozhi-creator-skill
```

## 能力范围

1. 创建智能体：`POST /api/agents`
2. 更新智能体：`POST /api/agents/<agent_id>/config`
3. 模型列表：`GET /api/roles/model-list`
4. 智能体列表：`GET /api/agents`
5. 设备列表：`GET /api/developers/devices`
6. 添加设备：`POST /api/agents/<agent_id>/devices`

## 文件结构

```text
xiaozhi-creator-skill/
├── SKILL.md
├── README.md
├── examples/
│   └── demo-conversation.md
├── references/
│   └── 主要接口_ai适配.md
└── .gitignore
```

## 致谢参考

- [alchaincyf/zhangxuefeng-skill](https://github.com/alchaincyf/zhangxuefeng-skill)

