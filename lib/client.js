window.__ModuleLoader__.load({
	id: "dsh-deepseek-balance",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		let react = require("react");
		let react_jsx_runtime = require("react/jsx-runtime");
		//#region lib/client/format.js
		/** 宿主侧注册的余额路由（由本包的宿主半边提供）。 */
		const ROUTE = "/dsh-deepseek-balance";
		/** 自动刷新间隔；点击指示器也会立即刷新。 */
		const REFRESH_MS = 5 * 60 * 1000;
		/** 各币种的显示前缀。 */
		const SYMBOLS = {
			CNY: "¥",
			USD: "$",
			EUR: "€"
		};
		/**
		* 把宿主返回的余额负载折叠成一条可渲染的摘要。任何失败都折叠成
		* `error` 相位而不是抛出，指示器因此始终渲染一个稳定形状。
		* @param payload - 宿主路由的响应体。
		* @returns 供指示器渲染的相位、主标签与悬浮详情。
		*/
		function summarize(payload) {
			if (!payload || payload.ok !== true) {
				return {
					phase: "error",
					label: "余额未知",
					detail: payload?.message ? `余额查询失败：${payload.message}` : "余额查询失败"
				};
			}
			const infos = Array.isArray(payload.balance?.balance_infos) ? payload.balance.balance_infos : [];
			const info = infos[0];
			if (info === void 0) {
				return {
					phase: "error",
					label: "无余额信息",
					detail: "账户未返回任何余额条目"
				};
			}
			const symbol = SYMBOLS[info.currency] ?? "";
			const parts = [`${info.currency ?? "?"}`];
			if (info.topped_up_balance !== void 0) parts.push(`充值 ${symbol}${info.topped_up_balance}`);
			if (info.granted_balance !== void 0) parts.push(`赠送 ${symbol}${info.granted_balance}`);
			return {
				phase: payload.balance?.is_available === false ? "error" : "ok",
				label: `${symbol}${info.total_balance ?? "?"}`,
				detail: `DeepSeek 余额 · ${parts.join(" · ")}`
			};
		}
		//#endregion
		//#region lib/client/BalanceAction.js
		/** 各相位的强调色，全部取自现有设计 token 以便随主题切换。 */
		const TONES = {
			loading: "var(--dsw-alias-label-tertiary, inherit)",
			ok: "var(--dsw-alias-label-primary, inherit)",
			error: "var(--dsw-alias-state-warn-label, #d97706)"
		};
		/**
		* 侧边栏底部的额度指示器：一个圆形币种标记加当前余额。
		* @param props - 侧边栏外壳传入的呈现参数；`wide` 为假时只留标记。
		* @returns 可点击刷新的余额控件。
		*/
		function BalanceAction(props) {
			const wide = props?.wide !== false;
			const [state, setState] = react.useState({
				phase: "loading",
				label: "…",
				detail: "正在查询 DeepSeek 余额"
			});
			const [hover, setHover] = react.useState(false);
			const alive = react.useRef(true);
			/**
			* 读一次余额。卸载后到达的响应直接丢弃，避免对已死的组件 setState。
			* @returns 无；结果通过 state 落地。
			*/
			const load = react.useCallback(() => {
				fetch(ROUTE, { headers: { accept: "application/json" } }).then((response) => response.json()).then((payload) => {
					if (alive.current) setState(summarize(payload));
				}).catch((error) => {
					if (alive.current) setState({
						phase: "error",
						label: "读取失败",
						detail: `余额查询失败：${String(error?.message ?? error)}`
					});
				});
			}, []);
			react.useEffect(() => {
				alive.current = true;
				load();
				const timer = setInterval(load, REFRESH_MS);
				return () => {
					alive.current = false;
					clearInterval(timer);
				};
			}, [load]);
			const mark = react_jsx_runtime.jsx("span", {
				"aria-hidden": "true",
				style: {
					display: "inline-flex",
					alignItems: "center",
					justifyContent: "center",
					width: "18px",
					height: "18px",
					flex: "0 0 18px",
					borderRadius: "50%",
					border: "1px solid var(--dsw-alias-border-l2, currentColor)",
					color: "var(--dsw-alias-brand-primary, currentColor)",
					fontSize: "10px",
					fontWeight: 700,
					lineHeight: 1
				},
				children: "¥"
			}, "mark");
			const label = react_jsx_runtime.jsx("span", {
				style: {
					overflow: "hidden",
					textOverflow: "ellipsis",
					whiteSpace: "nowrap"
				},
				children: state.label
			}, "label");
			return react_jsx_runtime.jsxs("button", {
				type: "button",
				title: `${state.detail}\n点击刷新`,
				"aria-label": `DeepSeek 余额 ${state.label}`,
				onClick: load,
				onMouseEnter: () => setHover(true),
				onMouseLeave: () => setHover(false),
				style: {
					display: "flex",
					alignItems: "center",
					justifyContent: wide ? "flex-start" : "center",
					gap: "8px",
					width: "100%",
					minWidth: 0,
					margin: 0,
					padding: wide ? "6px 10px" : "6px",
					border: "none",
					borderRadius: "8px",
					background: hover ? "var(--dsw-alias-interactive-bg-hover, rgba(127,127,127,0.12))" : "transparent",
					color: TONES[state.phase] ?? TONES.ok,
					font: "inherit",
					fontSize: "var(--dsw-font-base-16-font-size, 13px)",
					lineHeight: 1.4,
					textAlign: "left",
					cursor: "pointer",
					overflow: "hidden",
					transition: "background var(--ds-transition-duration-fast, 120ms) var(--ds-ease-in-out, ease)"
				},
				children: wide ? [mark, label] : [mark]
			});
		}
		//#endregion
		//#region lib/client/index.js
		/** 必需服务：UI slot 注册表。 */
		const inject = ["slots"];
		/**
		* 把额度指示器挂到侧边栏底部动作区，与设置入口同排。
		* @param ctx - 客户端根上下文。
		*/
		function apply(ctx) {
			ctx.slots.inject("sidebar.footer.action", () => ctx.slots.register({
				name: "sidebar.footer.action",
				id: "deepseek-balance"
			}, BalanceAction));
		}
		//#endregion
		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
