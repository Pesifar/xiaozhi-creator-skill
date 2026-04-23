# Xiaozhi Creator Skill 示例对话

以下示例用于演示 skill 的典型调用路径。

## 示例 1：创建智能体

用户：
请帮我创建一个智能体，名字叫“客服小智”，助手名“阿智”，模型先用 qwen。

助手（执行思路）：
1. 先调用 `GET /api/roles/model-list`，确认 `qwen` 在可用模型中。
2. 组装创建参数并调用 `POST /api/agents`。
3. 返回创建结果中的 `agent_id`。

助手（结果模板）：
- operation: create_agent
- status: success
- key_ids: agent_id=123456
- next_step: 如需更细配置，请继续执行 update_agent_config。

## 示例 2：更新智能体配置

用户：
把 123456 这个智能体语速改成 fast，音调改成 2，角色介绍更新一下。

助手（执行思路）：
1. 用完整配置体调用 `POST /api/agents/123456/config`。
2. 若失败，按错误码给出修复建议（如 `CHARACTER_LENGTH_LIMIT`）。
3. 提醒“更新后需要重启设备生效”。

助手（结果模板）：
- operation: update_agent_config
- status: success
- key_ids: agent_id=123456
- next_step: 请重启该智能体绑定设备使配置生效。

## 示例 3：添加设备到智能体

用户：
把验证码 778899 这个设备加到 123456 号智能体。

助手（执行思路）：
1. 调用 `POST /api/agents/123456/devices`，请求体 `{ "verificationCode": "778899" }`。
2. 成功后返回设备信息中的 `device_id` 和 `serial_number`。

助手（结果模板）：
- operation: add_device
- status: success
- key_ids: agent_id=123456, device_id=600608
- next_step: 可调用 get_device_list 验证设备在线状态。

