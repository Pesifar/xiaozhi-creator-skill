# xiaozhi-agent-creator-skill

将小智智能体创建流程封装为可安装的 skill（基于 `create_agent.py` + JSON 模版）。

## 安装（发布到 GitHub 后）

```bash
npx skills add Pesifar/xiaozhi-agent-creator-skill
```

例如（示例）：

```bash
npx skills add Pesifar/xiaozhi-agent-creator-skill
```

## 使用方式

1. 从模版复制配置文件：
   - `templates/agent_profile.template.json` -> `my_agent.json`
2. 编辑 `my_agent.json`：
   - `authorization.token`
   - `agent.agent_name`
   - `agent.assistant_name`
   - `agent.character`
3. 本地执行：

```bash
python scripts/create_agent.py --config my_agent.json --dry-run
python scripts/create_agent.py --config my_agent.json
python scripts/create_agent.py --config my_agent.json --sync-config
```

## 文件结构

```text
xiaozhi-agent-creator-skill/
├── SKILL.md
├── README.md
├── create_agent.py
├── scripts/
│   └── create_agent.py
└── templates/
    └── agent_profile.template.json
```

## 发布后如何让别人安装

1. 新建 GitHub 仓库（推荐名：`xiaozhi-agent-creator-skill`）
2. push 当前目录内容到仓库根目录
3. 确保仓库是 public（便于 `npx skills add user/repo` 拉取）
4. 他人执行：
   - `npx skills add Pesifar/xiaozhi-agent-creator-skill`

## 致谢参考

- [alchaincyf/zhangxuefeng-skill](https://github.com/alchaincyf/zhangxuefeng-skill)

