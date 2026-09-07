# Maccy 项目上下文

- 项目：/Users/kinso/code/github/kinsolee/Maccy；旧工作路径 /Users/kinso/Documents/ChatGPT/Maccy 为链接。
- 日期：2026-09-05。用户已确认 ADR-001 技术方案，并在 2026-09-05 23:07:25 +08:00 明确“UI用第 1 张作为任务目标”。架构与 UI 编码前置条件已满足。
- 技术基线：原生 SwiftUI/AppKit、SwiftData、KeyboardShortcuts、Defaults；复用现有单一 FloatingPanel。
- 真实场景：历史记录是顶部第一项，其他项为预设分组；拖历史内容到分组即保存副本；末尾加号新建组；无预设标题，搜索完整内容。
- 文件策略：用户明确选择独立副本。图片保存实际数据；视频仅按普通文件处理。
- 交互：首次历史、随后记住明确选择的组；删除失效组回历史；拖放不切组、不删除历史、不发送粘贴。
- 已选 UI 1：exec-36429f12-7630-487c-b34d-9de120a56b50.png；SHA256 39283aeec9d9bd7c1bcfed5b1869608a29c8f8cca4e5daaf0600ca8929d09470。
- 三张图片位于 /Users/kinso/.codex/generated_images/01a071aa-e39d-7fa3-bc2a-14cfddc16d8e/。更早的视觉稿已被替代。

## 已核验源码

- Maccy/Views/ContentView.swift:19：搜索、列表和按键容器目前绑定历史。
- Maccy/Observables/NavigationManager.swift:85：当前通过 UUID 路由历史和 footer，需要显式区分预设。
- Maccy/Storage.swift:28：当前容器注册 HistoryItem；孤儿清理只处理 HistoryItemContent。
- Maccy/Models/HistoryItem.swift:103：显示标题截断原文，图片调用 OCR；141 行文件内容主要是 URL。
- Maccy/Search.swift:59：搜索 title；fuzzy 存在 5000 字符上限。
- Maccy/Observables/HistoryItemDecorator.swift:181：高亮使用 500 字符标题；其 text 也有截断，不能当作完整搜索源。
- Maccy/Clipboard.swift:75：普通数据与文件 URL 有不同写入路径；文件用 writeObjects。
- Maccy/Popup.swift:175 和 Maccy/Views/KeyHandlingView.swift:165：释放修饰键及排队回调可能发送，管理和拖拽必须令旧回调失效。

## 证据等级与边界

上述为定向静态源码核验与独立只读审阅，不是运行、迁移或粘贴验收。尚未构建或测试应用。源码外动态行为、沙盒权限、焦点恢复和接收方文件读取必须按 implementation-plan.md 实测。不读取或保存真实用户剪贴板作为测试样本。
