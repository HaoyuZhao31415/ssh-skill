# ssh

把任意一次性的 SSH 登录命令标准化成可复用流程。

这是一个可本地复用、可上传到 GitHub、适合 OpenCode 斜杠命令调用的技能目录，面向 macOS 上的 OpenCode 工作流。它要解决的问题是：OpenCode 运行在你的 Mac 本地，但真正的训练、实验和远程操作往往发生在 Linux 服务器上，因此你需要一个通用、可重复使用、又不绑定任何固定机器的 SSH 入口。

## 技能名称与调用方式

技能名为 `ssh`，预期支持如下调用形式：

- `/ssh`
- `/ssh ssh -p 39300 user@host`

其中：

- 当你只输入 `/ssh` 时，技能应返回友好的用法说明。
- 当你输入 `/ssh ssh -p 39300 user@host` 时，可以把这次一次性命令标准化后交给脚本执行。

## 目录结构

```text
ssh/
├── README.md
├── SKILL.md
├── .env.example
├── .gitignore
├── ssh_connect.sh
└── agents/
    └── openai.yaml
```

各文件用途如下：

- `README.md`：使用说明，适合直接放到 GitHub。
- `SKILL.md`：OpenCode 本地技能元数据与提示词入口。
- `agents/openai.yaml`：斜杠命令展示名称与默认提示配置。
- `ssh_connect.sh`：真正执行 SSH 连接的 Bash 脚本。
- `.env.example`：示例环境变量模板。
- `.gitignore`：避免本地敏感配置误提交。

## 功能概览

`ssh_connect.sh` 支持两种主要输入模式：

### 模式 A：传入完整 SSH 命令字符串

适合把你临时拿到的一整条 SSH 命令直接交给脚本，例如：

```bash
./ssh_connect.sh "ssh -p 39300 root@some-host.com"
```

如果你是在技能上下文中通过 `/ssh ssh -p 39300 user@host` 传入参数，本质上也属于这一模式：完整 SSH 信息会先被标准化，再交给脚本处理。

也支持更简单的标准形式：

```bash
./ssh_connect.sh "ssh user@host"
./ssh_connect.sh "ssh -p 2222 user@host"
```

脚本会自动解析常见标准 SSH 形式，包括：

- `ssh user@host`
- `ssh -p 39300 user@host`

### 模式 B：显式参数传入

适合做成固定流程、脚本封装或长期复用：

```bash
./ssh_connect.sh --host some-host.com --user root --port 39300
```

也可以只传一部分，剩余部分从环境变量或 `.env` 读取：

```bash
./ssh_connect.sh --host some-host.com --user root
```

## 参数优先级

脚本按以下优先级决定最终连接参数：

1. 显式 CLI 参数
2. 传入后解析得到的完整 SSH 命令
3. 环境变量或本地 `.env`

默认端口为 `22`。

## 环境变量与 `.env`

脚本支持以下环境变量：

- `SSH_HOST`
- `SSH_PORT`
- `SSH_USER`
- `SSH_PASSWORD`

你可以复制示例文件：

```bash
cp .env.example .env
```

然后按需填写本地配置。脚本如果检测到同目录下存在 `.env`，会自动尝试加载。

示例：

```env
SSH_HOST=example.com
SSH_PORT=22
SSH_USER=root
SSH_PASSWORD=your_password_here
```

## sshpass 行为说明

### 当设置了 `SSH_PASSWORD` 且系统存在 `sshpass`

脚本会优先走非交互登录：

```bash
sshpass -p "$SSH_PASSWORD" ssh ...
```

### 当未设置 `SSH_PASSWORD`

脚本会回退到普通交互式 SSH：

```bash
ssh ...
```

### 当设置了 `SSH_PASSWORD` 但没有安装 `sshpass`

脚本会打印帮助提示，并回退到普通交互式 SSH。macOS 安装说明如下：

```bash
brew install hudochenkov/sshpass/sshpass
```

## 使用示例

### 1）直接执行完整命令

```bash
./ssh_connect.sh "ssh -p 39300 root@some-host.com"
```

### 2）只给出 `user@host`

```bash
./ssh_connect.sh "ssh dev@example.com"
```

### 3）拆分参数执行

```bash
./ssh_connect.sh --host example.com --user dev --port 2222
```

### 4）命令行覆盖 `.env`

假设 `.env` 中已有：

```env
SSH_HOST=example.com
SSH_PORT=22
SSH_USER=dev
```

临时改端口连接：

```bash
./ssh_connect.sh --port 2200
```

### 5）只用环境变量

```bash
export SSH_HOST=example.com
export SSH_USER=dev
export SSH_PORT=22
./ssh_connect.sh
```

## 推荐先赋予执行权限

```bash
chmod +x ssh_connect.sh
```

## 运行行为

脚本在真正连接前会输出一段友好摘要，说明将要连接的：

- 主机
- 端口
- 用户
- 当前采用的是交互式 SSH 还是 `sshpass` 非交互模式

如果缺少必要的 `host` 或 `user`，脚本会先报错并给出提示，不会盲目执行。

## 安全建议

- 不要把真实密码、主机、端口写进受版本控制的文件。
- 建议将 `.env` 保持在本地，并确保它已被 `.gitignore` 忽略。
- 更推荐优先使用 SSH key，而不是长期保存明文密码。
- 如果使用 `sshpass -p ...`，密码可能在本机进程列表中短暂可见，因此它更适合临时、本地、可控环境，不适合作为长期高安全方案。
- 如果只是临时登录，优先用一次性命令或本地未跟踪的 `.env`。

## OpenCode 集成说明

这个目录包含了最小可用的技能元数据：

- `SKILL.md`
- `agents/openai.yaml`

因此它适合作为一个本地可复用技能，供后续会话通过 `/ssh` 形式调用。

如果调用时没有附带参数，建议直接返回脚本帮助信息或提示用户使用以下形式：

```text
/ssh ssh -p 39300 user@host
```

## 许可证与复用建议

此目录设计为最小、实用、可读、可复用。你可以直接复制到自己的本地 OpenCode skills 目录中继续扩展，比如：

- 增加私钥参数支持
- 增加 `ProxyJump` 支持
- 增加连接别名映射

但默认实现刻意保持轻量，不内置任何真实目标配置。
