---
name: ssh
description: 将一次性的 SSH 登录命令整理为可复用流程。支持 `/ssh` 和 `/ssh ssh -p 39300 user@host`，也支持通过本地 `.env` 或环境变量补全主机、端口、用户与密码。
argument-hint: <ssh 命令或 --host/--user/--port 参数>
---

# ssh

将用户输入的 SSH 登录信息标准化，并引导其使用 `./ssh_connect.sh` 执行连接。

当前参数：`$ARGUMENTS`

## 行为要求

1. 如果 `$ARGUMENTS` 为空，先输出简洁友好的用法说明。
2. 提醒用户可用两种方式：
   - `/ssh`
   - `/ssh ssh -p 39300 user@host`
3. 告诉用户本技能目录下的脚本入口为 `./ssh_connect.sh`。
4. 如果用户提供的是完整 SSH 命令，按原意传给脚本，例如：
   - `./ssh_connect.sh "ssh -p 39300 user@host"`
5. 如果用户提供的是结构化参数，则按参数形式调用脚本。
6. 不要在技能文本中编造任何真实主机、账号或密码。

## 空参数时建议输出

当未提供参数时，可返回类似说明：

```text
用法示例：
- /ssh ssh -p 39300 user@host
- ./ssh_connect.sh "ssh user@host"
- ./ssh_connect.sh --host host --user user --port 22
```

## 最小说明

此技能用于把临时 SSH 登录命令转成统一、可复用、可审查的执行方式。
