# dsh SDK 快速入门：教学规划

> 状态：规划稿。不含教材正文，不含实现代码。
>
> 核对基线：`官方仓库 deepseek-ai/deepseek-harness`，commit `47f943859b`（2026-08-13），仓库版本 `0.1.0-rc.5`。本文所有 API、包名、字段名都来自这份仓库的原文；没有引用二手资料。
>
> 版本提醒：你说 PyPI 最新是 `0.2.2rc2`，但这份源码仓库是 `0.1.0-rc.5`，也没有找到 `0.2.2rc2` 对应的 tag。这是写作前必须拍板的第 2 个点（见 §7），不是可以含糊过去的小事。

---

## 0. 先说清楚这份材料怎么讲

### 0.1 两条线，一个骨架

- **看懂线（60 分钟）**：不追求覆盖所有子系统，只把「一个进程、一棵插件树、一条会话日志、三条接缝」讲透。
- **做出来线（3.5–4.5 小时）**：同一份代码从 `hello.py` 长到「有界面、能流式、有自己工具、真 key 不进引擎」的小应用。

整个材料只反复使用一张骨架图：

```text
一个 dsh 进程
├─ Cordis 容器（ctx）
│  ├─ ctx.llm        ← 模型面：谁把 token 变成流
│  ├─ ctx.tools      ← 工具面：模型能做什么动作
│  ├─ ctx.sessions   ← 会话日志：模型看到的历史从哪来
│  └─ ctx.agents     ← 回合：谁把上面三样串起来
└─ 传输层            ← 控制面：谁在跟这个进程说话
   ├─ stdio JSON-RPC（Python SDK / 你的 BFF）
   ├─ HTTP + SSE（Web UI）
   └─ 一次性 stdout（headless）
```

**三条接缝**是整份材料的骨架：

| 接缝 | 一句话 | 换它意味着什么 |
|---|---|---|
| 控制面 | 谁把用户的话送进去、谁把事件送出来 | 换前端、换语言、换部署方式 |
| 模型面 | 请求打到哪个 URL、用哪个 key、怎么流式返回 | 换模型、换网关、换 key 管理 |
| 工具面 | 模型能调用哪些工具、工具在哪里执行 | 换工具、接 MCP、关内置工具 |

StaffDeck 值得借的只有这三条分界线，不是它的 12 万行。教材会明确说：**三条缝各自独立，换一条不需要动另外两条**。

把 StaffDeck 的三个选择投影到这份材料，正好一一对应：

| StaffDeck 的做法 | 本教材的落点 | 只借什么 |
|---|---|---|
| 控制面走 stdio JSON-RPC | L0/L1/L2：SDK 启动引擎、`session.event` 流、BFF 投影成 SSE | 协议边界，不借它的客户端体量 |
| 模型面用本地 OpenAI 兼容网关 + 一次性 activation token | L4：引擎只拿 `act-...`，真 key 在网关 | key 不落引擎的思路，不借它的网关实现 |
| 工具面关掉内置工具、改挂自己的 MCP server | L3：删/disable 内置 tool row，加 `mcp-client`，MCP server 独立进程 | 工具面边界，不借它的工具数量 |

这样学员每做完一个阶段，都能把它映射回 StaffDeck 的一个选择，而不是「又做了一个 demo」。

### 0.2 五条写作规则

1. **先现象，后命名**：每章开头先给一个屏幕上能看到或能画出来的场景，再出现术语。
2. **一次最多引入三个新术语**：讲完三个，先给一个画面/例子，再讲下一组；不要一口气五个。术语第一次出现时，必须有一句「它在图上的位置」。
3. **每章末尾一道复述题**：不是选择题，是「用自己的话讲给同事听」的题。
4. **每个动手阶段先写验收现象**：看不到这个现象，就不算过，不靠「应该可以」。
5. **只引路径，不引行号**：源码行号会漂，路径和概念不会。

### 0.3 明确不讲的清单

60 分钟装不下，也不该装：

- Cordis 框架源码、HMR、插件的热替换细节；
- subagent 调度、workflow、Ralph、goal；
- compaction、token 计费、session fork；
- ACP、TUI、Web Client 插件开发；
- Windows 的 pwsh 分支（本教材的 SDK minimal 组合本来就不支持 Windows）。

这些只在「边界」处提一句，不展开。

### 0.4 课前 15 分钟检查

- Python 3.10+；`python -c "import sys; print(sys.version)"`。
- 一个可用的 `DEEPSEEK_API_KEY`；先确认它能直接调通官方端点，排除 key 本身的问题。
- 一个空的 `sandbox/` 目录；不要把公司代码、个人文件放进去。
- macOS 14+ arm64 或 Linux；Windows 直接换机器/容器，不要试图绕过 PTY。
- 只有 L3-A 需要：Node >= 22.19、pnpm、能完整 clone 官方仓库的磁盘空间。没有这些就默认走 L3-B。

---

## 1. 分章方案（1 小时速览）

| # | 章节标题 | 这一章讲什么（一句话） | 先给的画面 | 预计字数 | 分钟 |
|---|---|---|---|---|---|
| 1 | **先看见再命名：两个进程、一棵树、一条日志** | 从 `python hello.py` 的屏幕现象出发，建立「SDK 进程 + 引擎进程 + 会话日志」的三件套 | 终端吐出一句话；`ps` 里多了一个 `dsh-jsonrpc-agent-pkg-...` 进程（单文件 Node 运行时）；`sessions/` 下多了一层项目目录和会话目录，里面有 `session.jsonl` | 700 | 5 |
| 2 | **Cordis 五件事：插件、上下文、服务、事件、可逆注册** | 用「配电盘」讲清 `ctx.tools` / `ctx.llm` / `ctx.sessions` 为什么能被替换 | 每个插件插上去，配电盘上多一个 `ctx.xxx`；拔掉，注册的东西自动消失 | 1,300 | 10 |
| 3 | **一次 turn 的行车记录仪** | 把 `turn/start` 到 `turn/end` 的事件序列拆成「模型请求 + 工具执行」的循环 | 一次对话是一段行车记录：点火、每一帧、到站、熄火 | 1,400 | 10 |
| 4 | **三条接缝：控制面、模型面、工具面** | 换前端、换模型、换工具各自动哪一层；这是全篇的骨架 | 三根管道：一根送话，一根送 token，一根送动作 | 1,600 | 12 |
| 5 | **profile 与 dsh-base：同一台发动机，不同车身** | bundle 栈 + patch 的叠加顺序，以及为什么 patch 是整行替换 | 一张装机单：先装 base，再装 web-app/headless，最后贴自己的 patch | 1,000 | 8 |
| 6 | **SDK 只是遥控器** | `DeepSeekHarness` 的生命周期、`run()` 的活动区间、`events` 与 `notifications` 的差别 | 遥控器按一下，电视自己换台；遥控器不生产画面 | 900 | 7 |
| 7 | **收束：一张图、三句话、六个坑** | 用自测题把「能复述」变成「能判断」 | 把整棵树缩成一张 A4 图 | 1,000 | 8 |
| | **合计** | | | **7,900 字** | **60 分钟** |

### 每章的「一句话结论」

1. **ch1**：dsh 不是「一个 Python 库」，是「你的程序 + 一个被启动的引擎进程 + 一份可读的日志」。
2. **ch2**：插件不是「扩展点」，是「往共享上下文里注册服务/事件/效果」；注册是效果，卸载会回滚。
3. **ch3**：模型看到的历史不是内存里攒的，是从会话日志 `deriveMessages()` 投影出来的；**model-visible means logged**。
4. **ch4**：控制面只负责送话和收事件，模型面只负责 token 流，工具面只负责动作；三条缝不要互相渗透。
5. **ch5**：profile 是「具名组合」，bundle 是「可发行的 patch 层」，`dsh-base` 永远是第一层；patch 按 id 整行替换 config（或插入新行），不做深合并。
6. **ch6**：SDK 是控制面的一个 Python 客户端；`run()` 拥有一个从「prompt 的 durable inbox receipt」到「整个 agent 空闲」的活动区间。
7. **ch7**：能画出「三条接缝 + 一条日志」，能说出六个坑，才算真的看懂。

### 每章至少一个视觉锚点

图不装饰，图就是复述的脚手架：

- ch1：进程/日志图（你的 Python、引擎进程、`session.jsonl`）。
- ch2：配电盘图 + `emit`/`waterfall`/`parallel`/`serial` 四行表。
- ch3：turn 时序图（`turn/start` 到 `turn/end`，标出 durable vs live）。
- ch4：三条接缝表 + 一张「请求从浏览器到模型」的路径图。
- ch5：层叠图（bundle 层 → profile patch → home patch → `--patch`）。
- ch6：SDK 调用时序图（`__enter__` → `run()` → `on_notification` → `idle`）。
- ch7：一张 A4 总图（三条接缝 + 日志 + 六个坑）。

ch2 还要顺手讲一句 `!!js`：它是 Cordis loader 的表达式节点，不是 YAML 语法；看到 `!!js process.env.DSH_MODEL ?? 'deepseek-v4-flash'` 就知道是启动时求值。不展开 loader 源码，只讲「它不是魔法，是配置层的表达式」。

### ch7 固定的六个坑

教材只讲这六个，不临时加；其他坑放到对应阶段的「坑」里：

1. `minimal.cordis.yml` 是 `danger-full-access`，bash/editor 能改任何路径。
2. 这个 SDK 组合不支持 Windows（持久 PTY 要 POSIX）。
3. `run()` 是同步的，且拥有一个活动区间；不要在事件循环里直接调用它。
4. `RunResult.events` 只含根会话；`notifications` 含根 + 后代，二者不要混用。
5. 引擎的 stdout 是 JSON-RPC 协议；不要给引擎配置 stdout logger，诊断走 stderr（你自己的 BFF 可以正常打印）。
6. 子进程继承父进程环境；不显式覆盖 `DEEPSEEK_API_KEY`，真 key 会落进引擎。

---

## 2. 1 小时速览的分钟级时间分配

| 时间段 | 内容 | 学完能回答什么问题 |
|---|---|---|
| **0–5′** | ch1：两个进程、一棵树、一条日志 | ① dsh 跑起来时机器里有几个进程？② `RunResult` 里哪三个字段最该先看？③ 为什么会话日志是「源」而不是「副产品」？ |
| **5–15′** | ch2：Cordis 五件事 | ① 用一句话解释插件、上下文、服务、事件、可逆注册？② `ctx.tools` 和 `ctx.llm` 分别属于哪条接缝？③ 为什么说「没有特权内核」？ |
| **15–25′** | ch3：一次 turn 的行车记录仪 | ① turn 和 step 的区别？② `assistant/chunk` 和 `assistant/message` 哪个是权威？③ `tool/call` 和 `tool/result` 怎么配对？④ 哪些事件是 durable，哪些是 live？ |
| **25–37′** | ch4：三条接缝 | ① 控制面用什么协议、有哪些方法？② 模型面请求打到哪个 URL、带什么 header？③ 工具面怎么注册一个工具？MCP 工具叫什么名字？④ 三条缝各自由谁拥有？ |
| **37–45′** | ch5：profile 与 dsh-base | ① profile 和 bundle 的区别？② `dsh-base` 在第几层？③ patch 的叠加顺序？④ 为什么 patch 不能深合并？⑤ `--dump-config` 看什么？ |
| **45–52′** | ch6：SDK 只是遥控器 | ① `DeepSeekHarness` 什么时候启动子进程？② `run()` 的区间从哪到哪？③ `events` 和 `notifications` 差在哪？④ 为什么 `run()` 是同步的？ |
| **52–60′** | ch7：收束 + 自测 | ① 六个坑分别是什么？② 模型说「我查不到工具」，你先看哪一层？③ token 不吐字，你先看哪一层？④ 让你同事复述，你会先讲哪三句话？ |

**时间不够的降级方案**：只有 45 分钟时，ch5 只讲「profile = bundle 栈 + patch、patch 整行替换」两句，把 `--dump-config` 留作课后；ch7 的自测题改成课后作业。不要砍 ch3 和 ch4，它们是骨架。

---

## 3. 动手部分：五个阶段

### 3.0 总览

一个目录，五个 git tag，代码只长大不复制：

```text
app/
  engine.py              # L0–L4 都只经过这一个引擎入口
  app.py                 # L2 起：FastAPI + SSE
  static/index.html      # L2 起：一个页面
  mcp_server.py          # L3：自己的 MCP server
  gateway.py             # L4：本地 OpenAI 兼容网关
  cordis/
    minimal.cordis.yml   # L0–L2
    mcp.cordis.yml       # L3+
sandbox/                 # 一次性工作区，可随时删
sessions/                # 会话日志
```

| 阶段 | 一句话目标 | 屏幕上能看到什么 | 累计代码量（自己写的） | 对应哪一层 | 时间 | 累计 |
|---|---|---|---|---|---|---|
| **L0** | 装 SDK，跑通一句 hello | 终端一句话 + 一份可读的 `session.jsonl` | ~25 行 Python | 控制面 + 模型面 | 25′ | 25′ |
| **L1** | 看见引擎事件流 | 一行一个事件：`turn/start`、`assistant/chunk`、`tool/call`、`tool/result`、`turn/end` | ~60 行 Python | 会话日志 + 事件域 | 30′ | 55′ |
| **L2** | 长出界面 + SSE | 浏览器里文字逐字出现，工具调用先 pending 再 result | ~190 行（Python + HTML） | 控制面 → BFF → 浏览器 | 60′ | 115′ |
| **L3** | 换成自己的 MCP 工具 | 工具列表只剩 `mcp__ads__get_campaign`，调用返回你造的 campaign 数据 | ~280 行（A）/ ~240 行（B） | 工具面 | 60′（A）/ 30′（B） | 175′ / 145′ |
| **L4** | 摘掉真 key，走本地网关 | 引擎进程里只有 `act-...`；停网关就报 `TRANSPORT`；真 key 轮换不用重启引擎 | ~390 行（A）/ ~350 行（B） | 模型面 | 50′ | 225′ / 195′ |
| **复盘** | 画出三条缝，回答六个坑 | 一张自己画的图 + 一段能讲给同事听的复述 | — | 全部 | 15′ | 240′ / 210′ |

> 代码量只算你新增/改写的 Python、HTML、YAML；不算从官方仓库复制的 `minimal.cordis.yml` 原文。相邻两阶段的差就是本阶段新增：L0 25 行、L1 +35、L2 +130、L3 +90（A）/+50（B）、L4 +110。
>
> A = L3 自建 runtime（把 MCP 接回主应用）；B = L3 用 `npx @deepseek-ai/dsh` 侧车（不接回主应用）。两条路的差别见 §3.4。
>
> 如果「同一份代码连续长大」是硬要求，**L3 必须走 A**；B 只是保证今晚能看到 MCP 边界的退路，它不满足「同一份代码」。

**总时长**：A 路线约 **4 小时**，加 20–30 分钟缓冲 = **4 小时 20 分–4 小时 30 分**；B 路线约 **3 小时 30 分**，加 20 分钟缓冲 = **3 小时 50 分**。都在「一晚上」范围内。

> 如果你不熟 FastAPI/SSE，L2 按 90 分钟估，总时长加 30 分钟；仍然在一个晚上内，但要把 L3 设为 B 路线，别让 L2 的超时挤压 L3/L4。

---

### 3.1 L0：跑通一句 hello（25 分钟，~25 行）

**目标**：从零安装 `deepseek-harness-sdk`，用官方 `minimal.py` + `minimal.cordis.yml` 跑一轮，拿到 `RunResult`，并在磁盘上找到会话日志。代码里只出现一个 import：`from deepseek_harness import DeepSeekHarness`。

**屏幕现象**：

1. 终端打印一句模型回复，例如 `Hello! How can I help you today?`。
2. 打印 `finish_reason=completed`（或你显式打印的 `result.finish_reason`）。
3. `sessions/--<你的-cwd>--/<session-id>/session.jsonl` 存在；因为是 `compression: none`，可以直接 `less` 看到 `turn/start`、`assistant/message`、`turn/end`。

**关键动作**：

- 在独立目录 `sandbox/` 里跑，`cwd` 指 `sandbox/`，`session_root` 指 `sessions/`；两个目录分开。
- 把官方 `examples/jsonrpc-agent/minimal.py` 和 `minimal.cordis.yml` 复制进 `app/`，只改 `session_root`/`cwd` 的传参，不改配置内容。
- `DEEPSEEK_API_KEY` 只放在当前 shell 的环境里，不写进 `sandbox/` 的任何文件。

**对应哪一层**：

- 控制面：`DeepSeekHarness` 启动 bundled runtime，通过 stdio JSON-RPC 发 `initialize` / `session/prompt`，收 `session.event` / `session.status`。
- 模型面：`minimal.cordis.yml` 里的 `llm-deepseek` 把请求发到 `DEEPSEEK_BASE_URL`（缺省是官方端点），用 `DEEPSEEK_API_KEY`。

**验收（能说出来才算过）**：

- `DeepSeekHarness` 启动的是哪个可执行文件？为什么它「懒启动」？
- `run()` 返回的 6 个字段分别是什么？`final_response` 和 `finish_reason` 各自描述的是「哪一段」？
- `cwd` 和 `session_root` 的区别？为什么不能把 `session_root` 放在 `sandbox/` 里？

**必须点明的坑**：

- `minimal.cordis.yml` 用的是 **`danger-full-access`**；`bash` 和 `str_replace_editor` 可以修改 runtime 进程能看到的任何路径。教材要在 L0 第一段就用醒目框写：**只在一次性目录/容器里跑，不要把真 key、公司代码、个人文件放进 `cwd`**。
- 这个组合的 `bash` 超时是 300 秒，编辑器单次输出上限 16,000 字符；这不是「安全限制」，只是体验限制。
- 本教材的 SDK minimal 组合依赖持久 PTY，**Windows 不行**；macOS 14+ arm64 或 Linux。dsh 全量产品在 Windows 有 pwsh 分支，但不在本教材范围，不要混为一谈。

---

### 3.2 L1：看见引擎事件流（30 分钟，累计 ~60 行）

**目标**：不只拿 `final_response`，而是把 `on_notification` 变成一台「事件打印机」，亲眼看见 turn / step / chunk / tool 的顺序。

**屏幕现象**：

让它执行一句「用 bash 跑 `echo hello`，然后告诉我你看到了什么」，屏幕上按顺序出现（注意：工具调用之后还会有**第二个 step** 来让模型消化工具结果）：

```text
session.event  turn/start
session.event  step/start
session.event  user/message
session.event  assistant/chunk   (很多行，text 增量)
session.event  assistant/message
session.event  tool/call         name=bash  arguments="{\"command\":\"echo hello\"}"
session.event  tool/result       isError=false
session.event  step/end
session.event  step/start        ← 第二个 step
session.event  assistant/chunk
session.event  assistant/message
session.event  step/end
session.event  turn/end          reason=completed
session.status idle
```

**关键动作**：

- 加一个 `--trace` 开关；只打印 `notification.method == "session.event"` 且 `payload["sessionId"]` 等于当前 session 的事件。
- 每个事件只打印 `type` + 2–4 个关键字段，绝不打印完整 payload（否则一屏几千行）。
- 观察 `assistant/chunk` 的 `data.chunk.type == "text"` 和 `data.chunk.text`；还会看到 `reasoning` chunk，那是思考流，不是正文；观察 `tool/call` 的 `arguments` 是**原始 JSON 字符串**，不是 dict。

**对应哪一层**：

- 会话日志：`turn/*`、`step/*`、`user/message`、`assistant/*`、`tool/call`、`tool/result` 是 durable 事件，会进 JSONL。
- 事件域：`agent/pre-step`、`agent/request`、`llm/stream`、`tools/pre-execute`、`tools/execute`、`tools/post-execute`、`tools/result` 是 live 扩展点，不全会进日志；教材只用「看得到的事件」讲，不展开监听器。

**验收**：

- `assistant/chunk` 和 `assistant/message` 哪个是权威？为什么 UI 回放保留 chunk、派生历史却跳过 chunk？
- `RunResult.events` 和 `RunResult.notifications` 的差别？为什么子代理的消息不会替换根会话的回复？
- `session.status idle` 为什么是 `run()` 的结束信号，而不是某个 `turn/end`？

**坑**：

- 子代理通知会混进来；必须按 `sessionId` 过滤，否则你会以为主线多了事件。
- `tool/call.arguments` 不要假设是 dict；它是模型产出的原始字符串，可能不合法，UI 要容错。
- `assistant/chunk` 很密；教材要教「按 block index 聚合」，不要每个 chunk 建一个 DOM 节点。

**复述题**：「如果我只想看模型最终说了什么，我应该读 `events` 里的哪个事件？如果我想做打字机效果，我该读哪个事件？两者会不会重复？」

---

### 3.3 L2：长出界面 + SSE（60 分钟，累计 ~190 行）

**目标**：FastAPI 后端 + 一个 HTML 页面；`POST /api/chat` 触发一轮，`GET /api/events/{run_id}` 用 SSE 把投影后的事件推给浏览器；文字逐字出现，工具调用显示成卡片。

**屏幕现象**：

- 浏览器输入「列出当前目录，并用一句话解释你看到了什么」。
- 文字一个个出现，不是一次性刷出。
- 先出现一张「正在运行 bash」的 pending 卡片，然后变成「已完成」并带输出。
- 结束后显示 `finish_reason=completed`；输入框恢复可用。

**架构（教材要画这张图）**：

```text
浏览器
  │  POST /api/chat           GET /api/events/{run_id}  (SSE)
  ▼                             ▲
FastAPI（BFF）                  │ asyncio.Queue
  │  run_in_executor            │
  ▼                             │
工作线程：harness.run(..., on_notification=...)
  │                             │
  ▼                             │
SDK 子进程（引擎）── session.event / session.status ──┘
```

**关键动作**：

- `app.py` 维护一个 `run_id -> asyncio.Queue` 的字典；`POST /api/chat` 创建队列、启动线程池任务、立刻返回 `run_id`。
- 投影层只处理当前 `sessionId` 的 `session.event`；`session.status` 的 `idle` 用来发 `done`，不要把别的 session 或子代理事件混进来。
- `on_notification` 在**调用 `run()` 的那个工作线程**上被回调；它不能直接 `await queue.put()`，要用 `loop.call_soon_threadsafe(queue.put_nowait, event)`。
- SSE 生成器只发**投影后**的事件：`{kind: "text_delta", text}`、`{kind: "tool_call", name, arguments}`、`{kind: "tool_result", name, isError, text}`、`{kind: "done", finish_reason}`。不要把完整 `session.event` 丢给前端。
- `assistant/chunk` 里不只有正文：`chunk.type == "text"` 才是回答，`reasoning` 是思考流。第一版可以折叠或不显示 reasoning，但绝不能把它混进正文；否则页面会出现两段重复的话。
- 第一版不做历史重放；刷新页面就丢，这是故意的，把「日志回放」留到下一课。

**对应哪一层**：

- 控制面：BFF 是 SDK 的调用方；浏览器不直接碰引擎。
- 事件投影：你从 `session.event` 里挑出 UI 需要的最小字段；这是「控制面 → 你的协议」的翻译层，不是引擎内部事件总线。

**验收**：

- 能画出「浏览器 ← SSE ← 队列 ← `on_notification` ← SDK ← 引擎」五段链路。
- 能解释为什么不能在 `async def chat()` 里直接 `await harness.run()`。
- 能说出「停止按钮」的真实能力：官方协议没有 per-prompt cancel / session-close；停止只能停止前端等待或关闭 runtime，不能优雅取消引擎里的 turn。

**坑**：

- `run()` 是同步阻塞的；必须放线程池，否则整个事件循环卡死，SSE 一个字都出不来。
- `on_notification` 是工作线程；`asyncio.Queue` 不是线程安全的，必须 `call_soon_threadsafe`。
- 队列要有 `maxsize` 和超时；模型输出很快时，SSE 客户端断开会造成积压。
- **先连 SSE 再 POST**，或者让队列保留一小段 backlog；否则 `POST /api/chat` 已经跑出前几个 token，浏览器才连上 `GET /api/events`，第一段字会丢。
- 一轮结束后要发 sentinel，SSE 生成器才能退出；否则浏览器一直挂着。
- 启动失败（缺 key、runtime 起不来、MCP 没工具）也要推一个 `error` 事件再发 sentinel；否则前端只会看到「一直转圈」。

**复述题**：「如果浏览器只收到 `assistant/chunk`、没有收到 `assistant/message`，是引擎没发，还是你的投影层丢了？你先查哪一段？」

---

### 3.4 L3：换成自己的 MCP 工具（60 分钟 A / 30 分钟 B，累计 ~280 / ~240 行）

**目标**：模型看到的工具从「内置 bash/editor」变成「你写的 `mcp__ads__get_campaign`」，调用返回你造的 campaign 数据；控制面协议和模型面配置不用改，只换引擎的启动参数和 cordis 组合。

#### 先说一个必须知道的事实

按这份 `0.1.0-rc.5` 源码核对：

- `python/sdk-runtime/package.json` 是 SDK 单文件运行时的 deploy root，它的依赖列表里**没有** `@deepseek-ai/dsh-mcp-client`。
- `python/sdk-runtime/README.md` 明确说：想给发行版加一个插件，就是往这个 `package.json` 加一行依赖，然后重新构建。
- 所以，**只改 `cordis.yml` 加一行 `mcp-client`，按这份 0.1.0-rc.5 的 PyPI 包装出来的 SDK runtime 是加载不了的**。这不是配置写错，是插件根本不在那个单文件可执行文件里。

因此 L3 有两条可跑路线，必须二选一：

| | **L3-A：自建 runtime** | **L3-B：dsh 侧车** |
|---|---|---|
| 做法 | clone 仓库 → 往 deploy root 加 `@deepseek-ai/dsh-mcp-client` → 重编 runtime → 装 runtime wheel（或 `runtime_bin` 指 `dist-exe`） | `npx @deepseek-ai/dsh` 装一个独立 profile，`dsh plugin add` 装 `@deepseek-ai/dsh-mcp-client`，用 `--patch` 挂载 |
| 保住 L2 前端 | **是**，同一个 FastAPI 页面继续用 | **否**，这一段用官方 Web UI 看工具调用 |
| 时间 | 60′（含 30–45′ 构建，可与 L1/L2 并行） | 30′ |
| 风险 | 构建失败、版本对不上（SDK 与 runtime 必须同 commit） | 工具面能跑，但没接回主应用 |
| 适合 | 想把 MCP 接进最终应用 | 今晚先看见 MCP 边界 |
| 教材默认 | **推荐**，但设 45 分钟硬超时 | **自动降级**，超时就切 |

> 推荐策略：19:00 一开始就在另一个终端启动 L3-A 的构建，L1/L2 照常做；20:45 构建还没绿，就切 L3-B，不要为构建熬夜。最终应用的「有自己工具」只有 A 能给你；B 给你的是「看懂并跑通 MCP 边界」。
>
> 换句话说：**L3-B 是「保证能跑」的底线，L3-A 是「接回主应用」的目标。** 教材会把 B 写成主路径的降级分支，而不是失败后的补救；两者用同一个 MCP server、同一套工具名，切换成本很低。

#### L3-A 的具体步骤（教材里写成清单，不写实现代码）

> 构建前置：Node >= 22.19（`python/sdk-runtime/README.md` 对 dev node carrier 的要求）、pnpm、仓库依赖能装完。先把这条写在 L3-A 开头，避免学员卡在 Node 版本上。

1. **锁版本 + 加依赖**：clone 仓库到固定 commit；在 `python/sdk-runtime/package.json` 的 dependencies 里加 `@deepseek-ai/dsh-mcp-client`；`pnpm install`。
2. **构建 runtime**：`pnpm exec tsx scripts/build-exe-for-python-sdk.ts --targets=node24-macos-arm64`（Linux 换成对应 target；脚本默认会跑 `pnpm run build`，已有 `lib/` 时可加 `--skip-build`）。产物在 `dist-exe/`；macOS 的 `-spawn-helper` 兄弟文件由构建脚本一并产出并同步进 `python/sdk-runtime/`，不要手工只拷 exe。
3. **打 wheel + 安装**：按 `python/development.md` 的「Build distributions」流程，从同一 commit 打 **SDK wheel + runtime wheel**；`pip install --find-links dist-python deepseek-harness-sdk=="$version"`。不要直接 `pip install -e python/sdk`：SDK 依赖同版本的 `deepseek-harness-runtime-bin`，直接 editable install 容易解析不到本地 runtime。
4. **写 `mcp.cordis.yml`**：从 `minimal.cordis.yml` 删掉 `persistent-bash` 和 `str-replace-editor` 两行，加上一行 `mcp-ads`：
   - `transport: stdio`
   - `serverName: ads`
   - `command: /abs/path/to/venv/bin/python`（不要依赖 `python` 在 PATH 里；引擎进程的 PATH 可能和你的 shell 不同）
   - `args: ["/abs/path/mcp_server.py"]`
   - `failOnStartupError: true`（开发期必开；默认 `false` 会让 MCP 启动失败静默变成「没有工具」）
5. **写 `mcp_server.py`**：用官方 MCP Python SDK 的 stdio server，只暴露一个 `get_campaign(campaign_id: str)`，返回假数据 `{campaign_id, name, status, spend}`。
6. **改 `engine.py`**：只加 `cordis="mcp.cordis.yml"`；如果 runtime wheel 已经装进 venv，SDK 会自动找到 bundled runtime，**不需要** `runtime_bin`。只有你想绕过 wheel、直接指 `dist-exe/...` 时才传 `runtime_bin`。前端最多改工具卡片的显示名，不需要改链路。

**L3-A 屏幕现象**：

- 模型工具列表里只剩 `mcp__ads__get_campaign`，没有 `bash`、没有 `str_replace_editor`。
- 你说「查一下 campaign 123」，模型先调用工具，再回答 `campaign 123 是 ...，状态 ...，花费 ...`。
- 事件流里出现 `tool/call name=mcp__ads__get_campaign` 和对应的 `tool/result`。

#### L3-B 的具体步骤（不重编）

1. `npx @deepseek-ai/dsh web` 先确认官方 Web UI 能起（默认 `http://127.0.0.1:3080`）。
2. `npx @deepseek-ai/dsh plugin --profile web add @deepseek-ai/dsh-mcp-client`；这条命令转发给 profile 目录里的 pnpm，把包装进 profile 的 `node_modules`。
3. 写一个 `mcp.patch.yml`：插入 `mcp-ads` 行；把 `tool-bash`、`tool-fs`、`tool-fs-search`、`tool-str-replace-editor`、`tool-todo`、`tool-web`、`tool-subagent`、`tool-jobs` 这些模型面工具行 `disabled: true`（这不是完整列表；以 `packages/bundle/base/cordis.patch.yml` 的 row id 为准，逐个核对，最后用 `--dump-config` 确认没有漏网的内置工具）。
4. `npx @deepseek-ai/dsh --profile web --patch ./mcp.patch.yml`，在官方 Web UI 里做同一个 campaign 查询。如果 UI 弹出工具审批，点允许；那是 dsh 的 approval 层，不是 MCP 协议的一部分。
5. L2 的页面不动；这一段是「工具面」的对照实验。

**L3-B 屏幕现象**：

- 官方 Web UI 的工具列表/调用卡片里出现 `mcp__ads__get_campaign`；内置的 bash/fs 工具不再出现。
- 同一句「查一下 campaign 123」返回你造的假数据；工具卡片上能看到 MCP 的 server 前缀。
- L2 的 FastAPI 页面还在，但它这一轮没有接 MCP；这是 B 路线的明确代价。

> L3-B 有一个需要在目标版本上验证的点：`dsh plugin add` 对没有 `dsh.bundle` 声明的包只当作普通依赖安装，会打印警告；patch 里的 `mcp-ads` 行能不能按包名从 profile 的 `node_modules` 解析到，取决于该版本的 loader。如果报「找不到包」，先看 profile 的 `package.json` 是否真的有这个依赖，再决定用包名还是绝对路径；这一步要在正文里写成可排错的检查点，不能假设一次成功。

#### 两条路共同的坑

- `serverName` 必须是 `[A-Za-z0-9_-]{1,32}`；模型看到的工具名是 `mcp__<serverName>__<rawName>`，会被规范到 64 字符，必要时加 12 位 hash 后缀。不要自己拼一个「看起来像」的名字。
- `command` 用绝对路径的 Python（venv 的 `bin/python`），不要依赖 PATH；MCP server 的 `args` 也用绝对路径。引擎进程的工作目录和你的 shell 不一定一样。
- `failOnStartupError` 默认 `false`：MCP server 挂了，插件会「成功激活但没有工具」。开发期一定设 `true`，让错误在启动时炸出来。
- MCP stdio 子进程拿到的是 **scrubbed ambient env**，不是完整的父进程环境；要给它 secret 就在 `env:` 里显式传，不要指望它继承 `DEEPSEEK_API_KEY`。
- `toolCallTimeoutMs` 默认 60 秒；长查询要显式调大。
- **SDK minimal 组合没有 approval UI**：MCP 工具会直接执行。教程里的 `get_campaign` 是只读假数据，所以没问题；换成真实投放/改预算工具时，必须在 MCP server 内部做权限、审计、幂等，不能指望引擎弹窗。
- 关内置工具是「关 row」，不是「删代码」；在 SDK 组合里删掉那两行，在 dsh profile 里 `disabled: true`，两种做法都行，但教材要说清你关的是哪一层。

**对应哪一层**：工具面（`ctx.tools` + MCP client + 独立 MCP server 进程）。控制面不变，模型面不变。

**验收**：

- 能说出「内置工具关掉」具体关的是哪些 row、为什么关 row 就够了。
- 能说出 MCP server 是独立进程还是 in-process、它的 stdout 为什么不能随便打印。
- 能说出工具结果怎么回到模型：MCP `callTool` → `ctx.tools` 的 canonical value → `tool/result` → 下一次模型请求。
- 能解释 `mcp__ads__get_campaign` 这个名字是哪三个部分拼的。

**复述题**：「如果模型说没有 `mcp__ads__get_campaign`，你先查 MCP 连接、工具注册，还是模型 prompt？三者的现象有什么不同？」

---

### 3.5 L4：摘掉真 key，走本地网关（50 分钟，累计 ~390 / ~350 行）

**目标**：引擎进程的环境里只有一次性 activation token；真 key 只在网关（或 BFF）进程；一轮对话里模型可以请求多次，run 结束就吊销 token。

**屏幕现象**：

- `ps eww <引擎 pid>`（macOS 上用 `ps -E`，或平台对应的看环境变量的方式）里看不到 `DEEPSEEK_API_KEY=sk-...`，只能看到 `DEEPSEEK_API_KEY=act-...`（或者你自定义的变量名）。
- 把网关停掉，下一轮对话报 `TRANSPORT`，错误信息指向 `http://127.0.0.1:8787`。
- 拿一个已经吊销的 token 再启动，第一轮就 401。
- 在网关侧轮换真 key（网关重读配置或重启网关），引擎不用重启，下一轮自动用新 key。

**架构（教材要画这张图）**：

```text
引擎进程                          网关进程                      DeepSeek
DEEPSEEK_BASE_URL ──────────────► 127.0.0.1:8787/v1
DEEPSEEK_API_KEY=act-...  ──────► 校验 token / session / TTL
                                  替换 Authorization: Bearer <真 key> ──► api.deepseek.com
                                  ◄────────── SSE 流式回传 ◄────────────
```

**关键动作**：

> 先划清边界：`/activate`、`/revoke`、activation token 的格式，都是**教材自己的网关协议**，不是 dsh 的 API。dsh 侧只负责把 `base_url` / `api_key` 解析成适配器的 `baseURL` 和 `Authorization`；不要把自定义端点数成 dsh 的字段。

| 东西 | 住在哪个进程 | 引擎能看到吗 | 怎么轮换 |
|---|---|---|---|
| 真 `DEEPSEEK_API_KEY` | 网关（或 BFF） | **不能** | 网关重读配置/重启网关 |
| `act-...` activation token | 引擎的 `DEEPSEEK_API_KEY` | 能，它本来就要用 | 每个 run 一个，run 结束吊销 |
| `x-deepseek-harness-session-id` | 引擎 → 网关的请求头 | 能 | 每个 run 一个 |

1. 网关提供 `POST /activate`：BFF 用「本轮 run id + session id」换一个 `act-...`，记录 `{token, session_id, expires_at}`。
2. BFF 用 `DeepSeekHarness(base_url="http://127.0.0.1:8787/v1", api_key="act-...")` 启动引擎；SDK 会把这两个值写进子进程环境（`DEEPSEEK_BASE_URL` / `DEEPSEEK_API_KEY`）。如果你用的版本没有这两个 kwarg，就直接设置同名环境变量，效果一样。
3. 网关的 `/v1/chat/completions` 校验 `Authorization: Bearer act-...`。如果请求带了 `x-deepseek-harness-session-id`，再校验它是否和 token 绑定的一致；没带就只校验 token / TTL（适配器只在 `GenerateOptions.sessionId` 存在时发这个 header，不要把「一定带」写死）。通过后把 `Authorization` 换成真 key，转发到 `https://api.deepseek.com/chat/completions`，原样流式回传 SSE。
4. `run()` 结束，BFF 调 `POST /revoke`；TTL 兜底（按一轮 run 的最长时长设，例如 30 分钟，不要设得太短）。

**一个必须讲清的设计点**：

> **「一次性」是「一次 run 一个」，不是「一次 HTTP 请求一个」。**
>
> 一轮对话里，模型可能因为工具调用请求多次（step 1 请求 → 工具 → step 2 请求）。如果 token 在每个 HTTP 请求后就作废，第二次请求就会 401。教材把「一次性」定义为**一次 run / 一次引擎启动一个 token**，run 结束就吊销；这既符合「一次性」的直觉，也不会打断工具循环。如果你参考的项目把粒度定在「一次引擎启动」，原理相同，只是吊销时机不同。

**对应哪一层**：模型面（`ctx.llm` 的 baseURL 与 credential 解析）。控制面不变，工具面不变。

**验收**：

- 真 key 在哪个进程的内存里？引擎进程里有什么？BFF 进程里有什么？
- 为什么「把 key 放进环境变量」不等于「key 不落引擎」？子进程继承父进程环境这件事，你在哪里验证？
- token 的生命周期和 `run()` 的生命周期是什么关系？网关重启，正在跑的 run 会怎样？
- 为什么网关要校验 `x-deepseek-harness-session-id`（当它存在时）？不校验会怎样？

**坑（教材要逐条点明）**：

- **子进程继承父环境**：SDK 启动 runtime 时是 `os.environ.copy()` 再叠加配置；如果 BFF 的环境里有真 `DEEPSEEK_API_KEY`，引擎会继承它。必须显式用 `api_key="act-..."` 覆盖，或在启动子进程前从环境里删掉真 key。只「不传 key」是不够的。
- **`base_url` 拼路径**：适配器请求的是 `{baseURL}/chat/completions`；你的网关如果路由是 `/v1/chat/completions`，就把 `base_url` 设成 `http://127.0.0.1:8787/v1`，不要重复拼 `/v1`。
- **SSE 透传**：适配器带 `accept: text/event-stream`，并且依赖 `[DONE]` 结束；网关不要缓冲整个响应，也不要改写 SSE 帧，原样转发最稳。
- **日志脱敏**：网关不要打印 `Authorization`；BFF 不要打印 `act-...` 的完整值；`cordis.yml` 里只写 `apiKeyEnv: DEEPSEEK_API_KEY`，永远不写 key 字面量。
- **只监听 127.0.0.1**：网关是本地组件，不要 `0.0.0.0`；教程里的 demo 不需要 TLS，但生产需要。
- **不要用 `max_tokens` 当安全边界**：它是输出上限，不是权限。

**复述题**：「如果你在引擎进程里 `env | grep DEEPSEEK` 看到了真 key，最可能是哪一步漏了？给出两个不同的修法。」

---

### 3.6 收尾：15 分钟复盘

让学员不看材料，画出下面这张图，并口头解释每个箭头：

```text
浏览器 ──HTTP/SSE──► BFF ──stdio JSON-RPC──► 引擎
                      │                       ├─ ctx.llm ──► 本地网关 ──► DeepSeek
                      │                       ├─ ctx.tools ──► MCP server
                      └─ 真 key                └─ ctx.sessions ──► session.jsonl
```

然后回答三个问题：

1. 如果老板说「换成另一个模型」，你动哪一层？为什么另外两层不用动？
2. 如果老板说「接我们自己的广告投放工具」，你动哪一层？MCP server 应该由谁维护？
3. 如果安全团队说「真 key 不能进引擎」，你怎么证明它没进去？拿什么命令、看哪个进程、看哪一行日志？

---

## 4. 总时长与一晚上排期

### 4.1 时间账

| 路线 | L0 | L1 | L2 | L3 | L4 | 复盘 | 合计 | 加缓冲 |
|---|---|---|---|---|---|---|---|---|
| **A（自建 runtime）** | 25′ | 30′ | 60′ | 60′ | 50′ | 15′ | **240′ = 4h00** | **4h20–4h30** |
| **B（dsh 侧车）** | 25′ | 30′ | 60′ | 30′ | 50′ | 15′ | **210′ = 3h30** | **3h50** |

### 4.2 一个可执行的晚上（A 路线）

| 时间 | 做什么 | 备注 |
|---|---|---|
| 19:00–19:25 | L0：装 SDK、跑 hello、看 JSONL | 同时在另一个终端启动 L3-A 的 clone + pnpm install |
| 19:25–19:55 | L1：事件打印机 | 让模型跑一次 bash，确认 `tool/call`/`tool/result` |
| 19:55–20:55 | L2：FastAPI + SSE + 页面 | 这是最费时间的阶段，预留 60′ |
| 20:45 | **L3 构建检查点** | 没绿就切 L3-B，不要犹豫 |
| 20:55–21:55 | L3：MCP server + 配置 | A 路线：构建已绿就直接接；B 路线：30′ 就够 |
| 21:55–22:45 | L4：网关 + activation token | 先跑通，再做 `ps` 验证 |
| 22:45–23:00 | 复盘 + 画图 | 不复盘等于没学 |

**如果只有 3 小时**：L0 → L1 → L2 → L4，L3 用 B 路线做 20 分钟演示，或者把 L3 留到第二天。不要为了 L3-A 的构建牺牲 L2/L4 的完整跑通。

---

## 5. 打算引用的官方文件（路径级）

### 5.1 必读，写作时逐段对照

- `docs/user/guide/python-sdk.md`（及 `.zh.md`）：安装、示例、workspace/session、danger-full-access、POSIX 限制。
- `python/sdk/README.md`（及 `.zh.md`）：`DeepSeekHarness` 生命周期、`RunResult` 语义、`events`/`notifications` 差别、`cordis` 注入。
- `docs/architecture.md`：Cordis、profile/bundle、核心包、turn flow、session log、capability seams。
- `docs/cordis-primer.md`：插件、上下文、服务、`inject`、事件分派模式、可逆效果。
- `docs/tool-execution-pipeline.md`：`tools/pre-execute` → guards → `tools/execute` → `tools/post-execute` → `tools/result`。
- `docs/subsystems/session.md`：`turn/*`、`step/*`、`assistant/chunk`、`tool/call`、`tool/result` 的字段与 durable/live 区分。
- `packages/sdk/protocol/README.md`：stdio JSON-RPC 的方法、通知、无 cancel/session-close、stdout 是协议。
- `packages/sdk/server/README.md`：服务端职责、`initialize`、`session/prompt`、`session.event`、`session.status`。

### 5.2 例子与 SDK 实现

- `examples/jsonrpc-agent/minimal.py`、`minimal.cordis.yml`、`cordis.yml`、`README.md`。
- `python/sdk/src/deepseek_harness/api.py`、`models.py`、`client.py`（API 形状、`RunResult`、`Notification`、子进程环境）。
- `python/sdk-runtime/README.md`、`python/sdk-runtime/package.json`、`python/sdk-runtime/src/deepseek_harness_runtime/runtime/cordis.yml`（bundled runtime 的 deploy closure 与默认配置）。

### 5.3 模型面

- `packages/llm/llm-deepseek/README.md`（`apiKeyEnv`、`baseURL`、`DEEPSEEK_BASE_URL`、`/chat/completions`、SSE、错误码）。
- `packages/llm/llm-deepseek/src/adapter.ts`（`authorization: Bearer`、`accept: text/event-stream`、`x-deepseek-harness-session-id`；写作时只引路径，不引行号）。
- `docs/subsystems/llm-streaming.md`、`docs/cookbook/adding-an-llm-adapter.md`。

### 5.4 工具面

- `docs/subsystems/tools.md`（tool registry、schema、pipeline、Code Mode）。
- `docs/cookbook/adding-a-tool.md`（`defineTool`、`execute` 契约、输出 schema、UI card）。
- `packages/mcp/mcp-client/README.md`（stdio/streamable-http、`serverName`、`mcp__<serverName>__<rawName>`、`failOnStartupError`、reconnect、scrubbed env）。
- `docs/tool-catalog.md`（生成的工具目录；只用来核对名字，不抄行号）。

> 边界说明：dsh 仓库只提供 **MCP client**（`packages/mcp/mcp-client`）和它的配置契约；MCP server 本身、MCP Python/TypeScript SDK 的用法不属于 dsh 仓库的事实范围。教材写 L3 时，dsh 侧一律引上面的 README；MCP server 的实现细节标注为「MCP 官方文档」，不要伪装成 dsh 文档。

### 5.5 组合、profile、CLI

- `packages/bundle/base/README.md`、`packages/bundle/base/cordis.patch.yml`（第一层、row id、平台分支）。
- `packages/boot/app-boot/src/profile.ts`（`PROFILE_TEMPLATES` 只有 web/headless；其他 profile 由 `dsh plugin` 创建）。
- `apps/cli/README.md`（`--profile`、`dsh plugin`、`--dump-config`、layer order）。
- `apps/cli/package.json`（CLI 的安装闭包依赖 `@deepseek-ai/dsh-mcp-client`，所以 `npx @deepseek-ai/dsh` 自带它）。
- `docs/user/develop/basic/config.md`、`publish.md`（profile/patch/`dsh plugin add` 的官方教程）。

### 5.6 安全与边界

- `docs/subsystems/sandbox.md`、`docs/subsystems/permission-presets.md`。
- `packages/session/session-persistence-jsonl/README.md`（JSONL 目录布局、`compression: none`、`packed chunk rows`）。
- `docs/subsystems/web-server.md`（只是用来解释「官方 Web UI 的 HTTP/SSE 与 SDK 的 stdio 是两条控制面」，不深入）。

> 上述 `.md` 绝大多数有对应的 `.zh.md`；少数生成文件或源码旁注可能只有英文，写作时以仓库实际文件为准。不要引用仓库外的二手文章，也不要把 StaffDeck 的代码当 dsh 的事实来源。

---

## 6. 已核对的事实与边界（防止写错）

| 事实 | 出处 | 备注 |
|---|---|---|
| 仓库 LICENSE 是 MIT | `LICENSE` | 与你的基线一致 |
| 包名 `deepseek-harness-sdk`，import `deepseek_harness`，Python `>=3.10` | `python/sdk/pyproject.toml` | 与你的基线一致 |
| API：`DeepSeekHarness(provider=, model=, max_tokens=, cwd=, session_root=, cordis=).run(input, session_id=, on_notification=)` | `python/sdk/src/deepseek_harness/api.py` | 还有 `base_url`/`api_key` 配置字段；L4 可以用，也可以走环境变量 |
| `RunResult(session_id, final_response, finish_reason, events, notifications, session_root)` | `python/sdk/src/deepseek_harness/models.py` | `finish_reason` 是最后一个根会话 `turn/end` 的 kind，没有 turn 结束就是 `None` |
| `events` 只含根会话；`notifications` 含根 + 已知后代 | `python/sdk/README.md` | 子代理消息不会替换根回复 |
| `run()` 拥有从 prompt 的 durable inbox receipt 到下一次 whole-agent idle 的区间 | `python/sdk/README.md` | `final_response` 是区间内最后一条已提交的根助手文本 |
| `minimal.cordis.yml` 工具只有持久 `bash` + `str_replace_editor`；`danger-full-access`；`compression: none`；bash 300s；editor 16k | `examples/jsonrpc-agent/minimal.cordis.yml` | 教材必须点明 danger-full-access |
| SDK minimal 组合不支持 Windows（持久 PTY 要 POSIX） | `docs/user/guide/python-sdk.md`、`examples/jsonrpc-agent/README.md` | dsh 全量产品另有 pwsh 分支，不在本教材范围 |
| stdout 是 JSON-RPC 协议，不能加 stdout logger | `packages/sdk/server/README.md` | 诊断走 stderr |
| 协议没有 per-prompt cancel / session-close | `packages/sdk/protocol/README.md` | 停止按钮的真实能力要讲清 |
| `session.event` 的 payload 是 `{sessionId, event}`；`session.status` 有 `running`/`idle` | `python/sdk/src/deepseek_harness/api.py` | L1/L2 的事件过滤依据 |
| `assistant/chunk` 的 `data` 是 `{turn, step, chunk}`；text chunk 是 `{type:'text', index, text}` | `docs/subsystems/session.md`、`packages/core/session/src/chunk-rows.ts` | 打字机效果读它；派生历史跳过它 |
| `tool/call` 的 `arguments` 是模型产出的原始 JSON 字符串 | `docs/subsystems/session.md` | UI 要容错，不能假设是 dict |
| `llm-deepseek` 的 `apiKeyEnv` 默认 `DEEPSEEK_API_KEY`；`baseURL` 可由 `DEEPSEEK_BASE_URL` 提供；请求是 `{baseURL}/chat/completions` | `packages/llm/llm-deepseek/README.md`、`src/adapter.ts` | L4 的网关路由就按这个拼 |
| 请求头含 `authorization: Bearer`、`accept: text/event-stream`；有 sessionId 时再带 `x-deepseek-harness-session-id` | `packages/llm/llm-deepseek/src/adapter.ts` | 网关可以按 session header 绑定 token（存在时） |
| SDK 启动 runtime 时 `os.environ.copy()` 再叠加配置 | `python/sdk/src/deepseek_harness/client.py` | L4 的真 key 泄漏风险就在这 |
| SDK runtime 的 deploy closure 不含 `@deepseek-ai/dsh-mcp-client` | `python/sdk-runtime/package.json`、`python/sdk-runtime/README.md` | 按 0.1.0-rc.5 核对；0.2.2rc2 需预检 |
| `dsh-mcp-client` 配置：`transport`（stdio/streamable-http）、`serverName`、`command`/`args`/`env`/`cwd`、`url`/`headers`、`toolCallTimeoutMs`、`failOnStartupError`、`reconnect.*` | `packages/mcp/mcp-client/README.md` | 工具名 `mcp__<serverName>__<rawName>` |
| MCP stdio 子进程用 scrubbed ambient env | `packages/mcp/mcp-client/README.md`、`src/transport.ts` | 不要指望它继承真 key |
| `dsh-base` 是每个 profile 的第一层；patch 按 id 整行替换 config | `docs/architecture.md`、`packages/bundle/base/README.md` | 不做深合并 |
| 官方随包 profile 模板只有 `web`、`headless`；其他名字由 `dsh plugin` 创建 | `packages/boot/app-boot/src/profile.ts`、`apps/cli/README.md` | 你环境里的四个入口是安装/创建出来的 profile，机制相同 |
| `@deepseek-ai/dsh` 的安装闭包依赖 `@deepseek-ai/dsh-mcp-client` | `apps/cli/package.json` | L3-B 可行的依据 |
| 会话 JSONL 在 `<root>/--<cwd>--/<id>/session.jsonl`（`compression: none`） | `packages/session/session-persistence-jsonl/README.md` | L0 让学员自己找到它 |

**两处需要特别小心**：

1. **版本差**：源码仓库是 `0.1.0-rc.5`，你说 PyPI 是 `0.2.2rc2`。`base_url`/`api_key` 配置字段、`@deepseek-ai/dsh-mcp-client` 是否已进 runtime、默认配置的 row 名，都可能在 0.2.2rc2 变化。正文动笔前必须先定版本基线。
2. **Windows**：你的基线说「Windows 不行」，这对**本教材的 SDK minimal 组合**成立；但 dsh 全量产品的 `dsh-base` 已有 pwsh 分支。教材要写「本教材不支持 Windows」，不要写成「dsh 永远不支持 Windows」，否则会被懂行的人挑错。

---

## 7. 需要你先拍板的 5 个点

### 1）L3 走 A 还是 B？

- **A**：自建 runtime，把 `dsh-mcp-client` 编进去，MCP 接回 L2 的同一个前端；代价是 30–45 分钟构建 + SDK/runtime 必须同 commit。
- **B**：`npx @deepseek-ai/dsh` 侧车，30 分钟看见 MCP 工具，但不在 L2 的页面里。

我的建议：**A 为目标，设 45 分钟硬超时，超时自动切 B**。你需要拍板的是：你接受这个 timebox，还是今晚直接选 B、把 A 留到第二晚？

### 2）正文按哪个版本写？

官方仓库是 `0.1.0-rc.5`（commit `47f943859b`），你说 PyPI 最新是 `0.2.2rc2`。这两个不是同一份代码。

- 如果按 **0.2.2rc2** 写：我需要你允许我在**本工作目录**建一个临时 venv，装一份 0.2.2rc2 的 wheel，核对 `DeepSeekHarness` 的字段、默认 `cordis.yml`、runtime 的 deploy closure 是否已含 `mcp-client`；否则我只能按 0.1.0-rc.5 写，并在文首标注版本。
- 如果按 **0.1.0-rc.5** 写：所有事实都能落到源码仓库的原文，但可能和你实际 `pip install` 到的版本有差异。

你选哪个？

### 3）前端技术栈

- **FastAPI + 原生 HTML/JS + EventSource**（推荐）：L2 60 分钟，依赖少，SSE 一眼看懂。
- **Next.js/React**：更接近你们的生产前端，但 L2 会涨到 90–120 分钟，总时长可能超过一晚上。

我的建议：第一版用 FastAPI + 原生，把「SSE 投影」讲透；React 只作为「同一套 SSE 协议换客户端」的课后延伸。你确认吗？

### 4）L4 网关放哪？

- **同 BFF 进程**：代码最少，真 key 在 BFF 内存里；引擎子进程仍然拿不到。
- **独立 `gateway.py` 进程**（推荐）：隔离更清楚，`ps` 演示更有说服力，但多一个端口和一份启动脚本。

我的建议：独立进程。你确认吗？

### 5）MCP server 用什么写、demo 工具用什么域？

- **Python + 官方 MCP Python SDK 的 stdio server**（推荐）：和你的 BFF 同语言，40 行以内。
- **TypeScript**：更贴近 dsh 插件生态，但多一套 Node 工具链。

Demo 工具我倾向 `get_campaign(campaign_id)`，返回 `{campaign_id, name, status, spend}`，贴近真实业务场景，代入感强。你需要确认：这个假数据字段是否符合你们的口径？还是先用一个中性的 `get_weather(city)`？

---

## 8. 风险与备选

| 风险 | 概率 | 影响 | 备选 |
|---|---|---|---|
| SDK 版本与源码仓库不一致，字段/默认配置对不上 | 高 | 高 | 先做 §7 第 2 点的版本拍板；L0 前用 5 分钟预检 `pip show` / `import` / 默认 `cordis.yml` |
| L3-A 构建失败或超时 | 中 | 高 | 45 分钟硬超时，自动切 L3-B；L3-B 的 MCP server 代码可以原样复用 |
| L3-B profile 解析不到 `@deepseek-ai/dsh-mcp-client` | 中 | 中 | 检查 profile 的 `package.json`/`node_modules`；用绝对路径或改走 L3-A |
| MCP server 启动失败但静默无工具 | 中 | 中 | `failOnStartupError: true`；L3 验收先看工具列表 |
| SSE 卡住 / 浏览器断连积压 | 中 | 中 | 队列 `maxsize`、sentinel、客户端断开时取消生成器 |
| `danger-full-access` 误伤 | 高 | 高 | 一次性 `sandbox/`；真 key 不进 workspace；条件允许用容器 |
| activation token 做成「每请求一次性」导致工具循环 401 | 中 | 高 | 明确「一次 run 一个」；用工具循环做验收 |
| 真 key 被子进程继承 | 中 | 高 | 显式 `api_key="act-..."` 覆盖；用 `ps`/环境变量验收 |
| 学员把「Windows 不行」理解成「dsh 永远不行」 | 中 | 低 | 文首和 L0 都写「本教材的 SDK minimal 组合」 |

---

## 9. 下一步（等你拍板后）

1. 按 §7 的 5 个点定版本、路线、栈、网关位置、MCP 语言。
2. 先写 **L0 的 200 字开场 + 验收清单**，拿给你试读；你确认「先给画面」的节奏对了，再展开 60 分钟速览。
3. 60 分钟速览写完先做一次「同事复述测试」：不看稿讲三分钟，讲不清的地方就是教材要补的画面。
4. 动手部分按 L0→L1→L2 先跑通，再决定 L3-A/B；不要先写 L4 的网关，否则 L2 的 SSE 还没验证，排错会缠在一起。
