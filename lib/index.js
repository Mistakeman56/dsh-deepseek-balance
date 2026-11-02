/**
 * DeepSeek 额度指示器 —— 宿主侧。
 *
 * 注册一个只读 HTTP 路由，代浏览器查询 DeepSeek 账户余额。
 * API Key 始终留在宿主进程内，绝不发送给客户端。
 *
 * 本文件刻意不 import 任何 `@deepseek-ai/*` 包：插件安装在 profile 的
 * node_modules 下，无法解析 harness 自身的依赖树；`ctx.credentials.resolve`
 * 接受普通字符串引用，因此这里零外部依赖最稳。
 */

const DEFAULT_BASE_URL = 'https://api.deepseek.com';
const DEFAULT_API_KEY_ENV = 'DEEPSEEK_API_KEY';
const ROUTE_PATH = '/dsh-deepseek-balance';

/** 必需服务：HTTP 路由注册 + 凭证存储。 */
export const inject = ['webServer', 'credentials'];

/**
 * 注册余额查询路由。
 * @param ctx - 宿主 cordis 上下文。
 * @param config - 可选覆盖：`baseURL`、`apiKeyEnv`、`timeoutMs`。
 */
export function apply(ctx, config = {}) {
  const baseURL = String(config.baseURL ?? DEFAULT_BASE_URL).replace(/\/+$/, '');
  const apiKeyEnv = String(config.apiKeyEnv ?? DEFAULT_API_KEY_ENV);
  const timeoutMs = Number(config.timeoutMs ?? 15000);

  const reply = (res, status, body) => {
    res.writeHead(status, {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    });
    res.end(JSON.stringify(body));
  };

  const handler = async (req, res) => {
    if (req.method !== 'GET') {
      reply(res, 405, { ok: false, error: 'method-not-allowed' });
      return;
    }

    let resolved;
    try {
      resolved = await ctx.credentials.resolve(apiKeyEnv);
    } catch (error) {
      reply(res, 200, { ok: false, error: 'credential-error', message: messageOf(error) });
      return;
    }

    if (resolved === undefined) {
      reply(res, 200, {
        ok: false,
        error: 'no-credential',
        message: `未配置 ${apiKeyEnv}`,
      });
      return;
    }

    try {
      const upstream = await fetch(`${baseURL}/user/balance`, {
        method: 'GET',
        headers: {
          authorization: `Bearer ${resolved.value}`,
          accept: 'application/json',
        },
        signal: AbortSignal.timeout(timeoutMs),
      });

      const text = await upstream.text();
      if (!upstream.ok) {
        reply(res, 200, {
          ok: false,
          error: `http-${upstream.status}`,
          message: text.slice(0, 300) || `HTTP ${upstream.status}`,
        });
        return;
      }

      let balance;
      try {
        balance = JSON.parse(text);
      } catch {
        reply(res, 200, { ok: false, error: 'bad-json', message: '上游返回了非 JSON 响应' });
        return;
      }

      reply(res, 200, {
        ok: true,
        source: resolved.source,
        fetchedAt: Date.now(),
        balance,
      });
    } catch (error) {
      const timedOut = error?.name === 'TimeoutError';
      reply(res, 200, {
        ok: false,
        error: timedOut ? 'timeout' : 'request-failed',
        message: messageOf(error),
      });
    }
  };

  ctx.effect(
    () => ctx.webServer.register({ kind: 'exact', path: ROUTE_PATH, handler }),
    'dsh-deepseek-balance: balance route',
  );
}

/**
 * 把未知抛出物压成一行文本。
 * @param error - 捕获到的任意值。
 * @returns 可读的错误描述。
 */
function messageOf(error) {
  return error instanceof Error ? error.message : String(error);
}
