# dsh-deepseek-balance

DSH 插件：在 Web GUI 的**侧边栏底部**显示 DeepSeek API 账户余额剩余量。

```
[¥] ¥110.00      ← 展开态：币种标记 + 总余额
[¥]              ← 收起态（rail）：只留币种标记
```

- **hover**：背景高亮（沿用 `--dsw-alias-interactive-bg-hover`）
- **点击**：立即刷新
- **自动刷新**：每 5 分钟一次
- **状态色**：正常沿用主文本色，加载中为次要色，失败为警告色
- 悬浮提示显示明细：`DeepSeek 余额 · CNY · 充值 100.00 · 赠送 10.00`

## 前置条件

1. 已安装 DSH，且版本 ≥ `0.2.0`（`dsh --version` 可查）。
   本包在 `0.2.1-rc.5` 上验证通过；`0.1.x` 的侧边栏 slot 名称不同，不保证可用。
2. 要装的那个 profile 里**已经配好 `DEEPSEEK_API_KEY` 凭证**——插件靠它查余额。
   如果日常已经能用 DeepSeek 模型对话，这一步通常已经满足了。

## 安装（推荐：一行命令，从云端装）

```sh
curl -fsSL https://cdn.jsdelivr.net/gh/Mistakeman56/dsh-deepseek-balance@v0.1.1/bootstrap.sh \
  | bash -s -- --ref v0.1.1 --profile web
```

它会拉取插件文件、装进目标 profile、登记补丁条目，然后提示你刷新页面。

- 默认装到 `web` profile（`dsh web` 用的就是它）；换 profile 改 `--profile <名字>`
- 大陆网络下优先走 jsDelivr（上面这条），raw.githubusercontent.com 多数时候不通
- 如果 jsDelivr 也不通，可以用 GitHub 原始地址（需代理）：

  ```sh
  curl -fsSL https://raw.githubusercontent.com/Mistakeman56/dsh-deepseek-balance/v0.1.1/bootstrap.sh \
    | bash -s -- --ref v0.1.1 --profile web
  ```

脚本内部有多镜像回退（jsDelivr → raw → github raw），任意一个通就能装上。

## 安装（离线包 / 已有 tgz）

```sh
tar -xzf dsh-deepseek-balance-0.1.1.tgz
cd package
./install.sh --profile web
```

## 安装（pnpm 方式，需手动登记）

```sh
dsh plugin --profile web add \
  https://github.com/Mistakeman56/dsh-deepseek-balance/releases/download/v0.1.1/dsh-deepseek-balance-0.1.1.tgz
```

这条只把包装进 `node_modules`，**还要**按下面“手动，不想跑脚本”的第 2 步登记
loader 条目，否则插件不会加载。所以一般直接用上面的 `curl | bash` 更省事。
注意：GitHub 的 Release 下载在国内常被墙，需要代理。

## 安装脚本做了什么

脚本只做两件事：

1. 把包文件复制到 `~/.dsh/profiles/<profile>/node_modules/dsh-deepseek-balance/`
2. 在该 profile 的 `cordis.patch.yml` 里登记一条 loader 条目（写之前会备份）

选项：

| 参数 | 说明 |
| --- | --- |
| `--profile <name>` | 装到哪个 profile，默认 `web`（`dsh web` 用的就是它） |
| `--home <path>` | DSH home 目录，默认 `$DSH_HOME` 或 `~/.dsh` |

幂等：重复执行不会重复写入补丁。安装完会尝试用 `dsh --dump-config` 自检一次。

最后**重启 `dsh web` 或刷新浏览器页面**即可。多数情况刷新就够了。

## 安装（手动，不想跑脚本）

1. 把整个包目录放到：

   ```
   ~/.dsh/profiles/<profile>/node_modules/dsh-deepseek-balance/
   ```

2. 编辑 `~/.dsh/profiles/<profile>/cordis.patch.yml`，在 **已有的** `insert:` 列表里
   加两行（没有 `insert:` 就新加一个块）：

   ```yaml
   - insert:
       - id: deepseek-balance
         name: dsh-deepseek-balance
   ```

3. 刷新页面。

> 注意：直接 `dsh plugin --profile web add <包>` 只会把包装进 `node_modules`，
> **不会**自动登记 loader 条目。第 2 步不能省，否则插件不会被加载。

## 配置（可选）

在补丁层里给条目加 `config`：

```yaml
- insert:
    - id: deepseek-balance
      name: dsh-deepseek-balance
      config:
        baseURL: https://api.deepseek.com   # 自建/代理端点
        apiKeyEnv: DEEPSEEK_API_KEY         # 凭证名
        timeoutMs: 15000                    # 上游超时
```

## 工作原理

| 半边 | 职责 |
| --- | --- |
| `lib/index.js`（宿主） | 用 `ctx.credentials` 取 `DEEPSEEK_API_KEY`，注册只读路由 `GET /dsh-deepseek-balance`，代查 `https://api.deepseek.com/user/balance` |
| `lib/client.js`（浏览器） | 通过 `ctx.slots` 把指示器挂到 `sidebar.footer.action`，`fetch` 宿主路由取数并渲染 |

**API Key 永不离开宿主进程**：浏览器只拿到余额数字，拿不到凭证。

`client.js` 是预构建好的 `__ModuleLoader__` 模块，**不需要本地构建**，装完即用。

## 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 侧边栏没有指示器 | profile 名填错；或没重启/刷新；或补丁条目没写进 `cordis.patch.yml` |
| 显示 `未配置 DEEPSEEK_API_KEY` | 该 profile 没有这个凭证，先配好 API Key |
| 显示 `余额查询失败：HTTP 401` | 凭证无效或已过期 |
| 显示 `余额未知` | 上游不可达，检查网络或代理，必要时配 `baseURL` |
| 想确认路由是否活着 | 浏览器直接访问 `http://127.0.0.1:3080/dsh-deepseek-balance` |

## 卸载

```sh
./uninstall.sh --profile web
```

会删除包目录，并从补丁层移除登记的条目（先备份补丁）。

## 版本

- `0.1.1` — 修复云端安装：逐文件拉取 + 多镜像回退，国内网络可用
- `0.1.0` — 首个版本
