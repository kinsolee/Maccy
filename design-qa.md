# UI 1 运行验收

final result: passed (2026-09-07) — 拖放真根因(isFloatingPanel 阻断拖放目标事件)修复后,用户真人拖放验证通过;自动粘贴此前已确认;窗口动画竞态已同步帧方案根因修复,114/0 回归通过。两项产品调整(新分组置顶、删除免确认)已实施。详细记录见 docs/tasks/grouped-presets.md 交付检查点。

- 源视觉：[UI 1](/Users/kinso/.codex/generated_images/01a071aa-e39d-7fa3-bc2a-14cfddc16d8e/exec-36429f12-7630-487c-b34d-9de120a56b50.png)，1355×1161。
- 最终39项代码/测试清单 `/tmp/Maccy-presets-window-final-candidate.json`，SHA256 `29179423e9d2decef25b7b56983610c8224508541ee2969c955bec8f47e6632b`。
- 实际列表：[450×295](/tmp/Maccy-window-list-fixed.jpg)；实际编辑：[450×379](/tmp/Maccy-window-editor-fixed.jpg)。原生AppKit/SwiftUI，完整截图，JPEG。
- [修复后同页对照](/var/folders/ff/h41djcp96771w7h20r155zkh0000gn/T/Maccy-presets-live-nidqcall/comparison-fixed.html)已在实际浏览器查看。源图裁去外部画布（约x268、y89、846×966），以CSS归一为主内容宽450；实际图保持450宽。没有重绘、替换素材或隐藏应用空白。
- 状态差异：源图为历史拖拽、八条示例；实际为客服话术分组三条合成预设及编辑。不能据此认定同状态逐像素保真；仍需真实鼠标拖放和用户视觉确认。

## 本轮已通过

1. 实际从完整预览切入编辑，窗口由850收为450宽，右侧400空白消失。高度更新取消独立整帧动画；预览动画中延迟高度，只有最新动画回调可以应用最新高度。新增隐藏真实NSPanel回归覆盖左右位置、两种resize顺序、快速往返和中途高度变化。
2. 新回归曾实际捕获旧closing回调误认新closing；保留全部断言，用最小动画序号修复。最终六类57/57通过、0失败、0跳过；`/tmp/Maccy-presets-window-final-regression.xcresult`及同名-summary.json。独立受影响补审SHIP，39项起止哈希匹配。
3. 原全文摘要换行遮挡已修复；实际列表可见尾部命中，正文/Unicode保持完整。预设已能打开全文预览。
4. 单独视频原生导入已通过；移走所选导入源后，实际预设复制、Finder手工Cmd+V到received，2246字节及SHA256 `5b691853429d430e99a34f342e9e916d5e8cf9808b2c85c86a04b2774b1eeba9`一致。这是文件生命周期及手工回贴，不是自动粘贴或视频播放验证。

## 剩余证据缺口

- 图片真实拖入分组：新Sky自动拖放后控件禁用，无新增；等待约60秒及Escape未立即恢复，点击目标后恢复并切组，仍仅原有两条内容。未据此认定产品永久锁死；只读诊断建议用户实际鼠标验证目标高亮、释放后恰好新增一条、留在历史且恢复可用。没有重复相同自动拖放或扩修猜测问题。
- 图片原始图像类型保存及回贴未live verified；文件导入不能替代图像拖放路径。
- 多文件原生选择未成功，已取消且没有半成品；本轮单独视频导入不冒充多文件验证。多文件顺序/同名文件独立拷贝仅unit verified。
- 用户已批准添加独立验收应用并完成系统身份验证。精确选择应用后，实际Option+Return通过Accessibility.allowed检查，转为“目标窗口已改变”，专用空白TextEdit未写入。系统列表暂未显示条目，但不能据此否定实际信任检查结果。当前等待用户从真实目标窗口打开验收Maccy并亲自执行Option+Return，再由主控读回；不能以手工Cmd+V替代。
- IME输入确认不误发、热键循环与菜单交叉，以及最终人工视觉确认仍待验。

## 五项保真检查

- 字体：原生系统字体、紧凑层级，中文/emoji可读；不声称字体逐像素匹配。
- 间距与布局：顶部组栏、搜索和手动添加、单列条目、底部键位说明对应；本轮列表和编辑均为450宽，无额外空白。保留Maccy标题和预览按钮，交用户判断。
- 颜色：浅色原生底色与蓝色选择态可见；拖拽hover颜色仍待真实投放确认。
- 图片质量：历史内合成图片可见；尚无成功保存后的同状态图片预设截图。
- 文案：历史、客服话术、手动添加、拖到分组即可保存、键位图例可见，无标题字段。

构建、57项测试、独立代码补审及窗口修复已通过；本页保留完整交互/人工验收缺项，不判定整个任务完成。

## 本轮采集隔离纠正

最初临时设置ignoreEvents=true、ignoreOnlyNextEvent=true只忽略了一次变更，生产Maccy提前恢复采集。恢复前检测到两键false，未盲覆盖；只读源码诊断确认机制后，精确恢复为原先两键均不存在。限于本次唯一附件路径的只读核对确认生产历史现有1条合成视频记录，没有删除或修改历史。后续验证重新备份为preference-backup-20260906-0104，并设ignoreOnlyNextEvent=false、ignoreEvents=true，实际读回；本轮结束前也已精确恢复原始absent并读回。

人工反馈续查：用户回复“我无法在搜索框输入”。root读取QA时搜索框可见、enabled、focused，定向普通n事件能显示n，但不代表用户物理键盘焦点正确。当前等待用户区分中文输入法、英文也失败或有字但不筛选。只读导航补查未发现当前菜单栏打开/普通无修饰字符吞键的新分支；不据此添加NSApp.activate，以免破坏原目标捕获。另发现独立P2：searchVisibility=duringSearch且空query时HeaderView不创建输入控件，可能无法接收第一个字符；当前QA该偏好absent沿默认always，且报障读回有可见框，不与当前故障混同。此P2暂未修复，代码仍为39项冻结版本；普通源码/测试检查不替代物理输入验收。


2026-09-06 自动粘贴根因与待裁决：用户确认输入已恢复；真人Option+Return仍被目标提示拦截。01:23:33.016的sandboxd真实日志精确命中QA PID28620，拒绝`mach-lookup com.apple.axserver (per-pid)`，堆栈落在PasteTarget.capture→focusedWindow→AXUIElementCopyAttributeValue。新增AX读取被现有App Sandbox拒绝，使window=nil；当前提示不能证明目标实际改变。脱敏证据为fixture目录paste-target-sandbox-denial.json，源日志SHA256 482d2e86213c2c9e700d35028fa608036f065188dfd84302219d28f75e13e037。无需再由用户重复原样粘贴或授权；源码仍为39项冻结候选，当前正向自动粘贴验收blocked。

待批准方案paste-recovery-v1：删除跨进程AX窗口读取，沿用原Maccy发键机制，并保留原前台应用在发送前/关闭后仍存活且位于前台的双检查、管理/拖放锁和generation。将唯一popup历史栈自动发键分支也接入同一应用检查，普通无popup Intent保留原行为与管理锁。更新中英文失败文案和合同说明。无需更改sandbox、权限、Clipboard发键实现或FloatingPanel。明确取消原方案对同应用内窗口身份的保证，必须用户批准这个取舍后实施。独立方案审查PASS只覆盖调整后的方案；不是旧合同通过。范围AppState+Presets.swift、History.swift、必要PresetPickerTests、两种Localizable.strings及已批准后对应说明。验收为原目标实际自动插入、跨应用切换拒绝、锁/过期回调无发送、权限不足仍可复制；同应用窗口切换限制如实标注。plan=2、delivery=2保持，本次尚未批准或实施。详见权威INDEX；本轮未操作GUI、剪贴板、生产偏好或用户历史。


paste-recovery-v1经用户批准后已实现、构建并通过独立代码补审，新39项清单SHA256 4927e4436dc40968fc42c582bc515dd8742efb4d14e9987069b9fa219fd6c742。改用应用身份保护，保留沙箱；同应用内部切换窗口不检测。42项相关测试41通过、1项原有窗口快速动画测试失败；停止并行构建后单项诊断通过，但不据此抹去失败或认定窗口竞态已修复。源码、断言未放宽；新QA PID72003保持独立容器，等待真人Option+Return实际插入。原57/57和窗口视觉结论为此前检查点，不能替代本次发现。


本轮结束读回：013649生产采集备份的两项偏好均已精确恢复原始absent，restored.txt和runtime receipt已更新；39项代码指纹仍一致，开发/集成树diff检查通过。QA72003与LEFT|RIGHT文稿保留供用户实际验证；尚未收到自动插入结果。下次主控写入合成剪贴板前重新备份并持续暂停生产采集，不假定旧暂停仍有效。未提交、集成、推送或完成归档。


辅助功能环境恢复（当前入口更新）：用户仍被权限提示阻止。真实tccd日志明确旧ad-hoc cdhash要求校验新构建返回-67050；临时产物也无可解析的Launch Services注册，精确tccutil reset首先以-10814失败。单路径注册未改变空查询后，root备份原产物、停止QA72003，使用现有Apple Development身份原生重建签名（源码39项未变），并复制到独立`/Users/kinso/Applications/Maccy Presets QA.app`。新入口strict/deep签名验证通过、原sandbox entitlement保持，系统精确查询唯一返回该路径，随后仅此BID的Accessibility reset成功。新副本尚未启动/取得新授权，系统设置辅助功能页添加按钮已准备，等待即时确认；不能把reset成功当作已授权或已粘贴。来源fixture/accessibility-stale-signature.json，构建/tmp/Maccy-presets-stable-signing-build.log，旧完整备份/tmp/Maccy-qa-permission-backup-20260906-015229/Maccy.app。生产设置/历史本轮未写入，旧41/42加单项诊断结果及未解决窗口回归保持原结论。


2026-09-06 02:00 +08:00：用户于01:58:07明确“允许”为稳定签名验收版添加辅助功能。主控核验CDHash仍为385e48660acd26ced7813f4addaeb64e981d56b1及39项源码冻结后，点击系统设置的添加；系统停在触控ID或密码验证，尚未进入选应用或写入权限。已请用户在本机完成验证，不收集密码、不重复索要已有许可。当前验收app尚未启动，生产采集偏好沿013649恢复结果保持未改，未进行新剪贴板或业务数据操作。原41/42回归及窗口动画未解状态不变。


2026-09-06T09:00:33.032884+08:00：用户再次回复“好了”后，实际系统设置辅助功能列表已显示“Maccy Presets QA”且开关on；不重复添加。已启动稳定签名副本，精确进程PID55600确认。当前新阻塞为启动前App Sandbox等待：secinitd 08:56:45.302记录新development签名不在旧同BID测试容器ACL并正在请求确认；进程采样停在_libsecinit_appsandbox，尚未进入应用/SQLite初始化。主控精确日志已核验，脱敏证据fixture/stable-qa-container-confirmation.json，源SHA256 d46fe05034599f984f5801c9c6b06d8c039288032a4a649b35a69a5c02f29132。权限开关on不等于容器访问获准或自动粘贴成功。未继续重启、重签、reset或改容器。已询问用户是否看到对应原生弹窗。只读核验UserNotificationCenter宿主实际运行，但Computer Use对该系统组件返回安全禁止；停止该UI路径，等待用户在本机处理。确认后须读回实际独立SQLite路径再验收。没有本轮剪贴板写入，生产ignoreEvents/ignoreOnlyNextEvent仍为absent。源码39项不变、自动计数2/2和窗口问题仍保留。


2026-09-06T09:26:28.501294+08:00：用户反馈没有看到弹窗后，主控与只读诊断分别核验到同一PID55600已经打开独立QA容器的Storage.sqlite及wal/shm；原启动等待事实已解除，未重启、重签、reset或修改容器，授权如何完成未知。QA窗口真实可读且客服话术合成预设仍在。TextEdit已准备LEFT|RIGHT、光标位于|前，待用户从菜单栏打开QA并Option+Return实际插入；工具定向发键不能替代全局菜单/热键交互。生产采集两键已备份至fixture/preference-backup-20260906-092449-stable-live，持续暂停，本轮结束前须按原始absent恢复。辅助功能开关开启及数据库读回已通过，自动粘贴仍待验收。


2026-09-06T09:27:20.611399+08:00：本轮结束前092449生产采集偏好两键已恢复原始absent并读回，restored.txt已保存；QA55600与专用TextEdit文稿留待用户实际Option+Return验收。尚未取得本版本自动插入正向结果，未新增代码修改或测试通过声明。


2026-09-06T09:35:05.584854+08:00：用户09:33:18明确“可以插入”，在本任务Option+Return验收请求后确认自动插入成功，记录为自动粘贴人工确认通过，不再重复辅助功能授权。主控当前读到的TextEdit文稿仍是原合成基线，未取得该次具体正文及目标的独立读回，因此不扩大为完整文本一致性/跨应用保护/全部AC-06通过。收据fixture/automatic-paste-user-confirmation.json；39项源码指纹和开发/集成树diff检查通过。生产偏好沿092449已恢复状态保持未改。

待裁决的最小窗口修复preview-synchronous-frame-v1已由原独立评审者审查PASS，尚未批准/实施。仅修改SlideoutController.swift：取消250ms的异步SwiftUI/NSAnimationContext/window.animator帧动画和无用回调字段，复用当前尺寸/左右放置计算，同次setFrame；设置期间保留opening/closing防误保存尺寸，返回前即稳定open/closed。保留原顶边、管理锁、选择、自动打开延时及抑制行为，FloatingPanel/Popup无需行为改动。UI取舍为历史和预设的预览改成立即展开/收起。保留原失败测试的全部有效断言及等待，批准后重构建、单项及必需回归、实际可见窗口验证。plan=2/delivery=2保留，需新的具体人工裁决；原41/42结果不被方案审查替代。

2026-09-06T10:31:23.793640+08:00：history-drag-source-v1 已实施：DragView 原生 mouseDownCanMoveWindow=false，并增加一项属性回归，其余鼠标/投放/结束处理不变。增量独立审查 SHIP；单次 PresetPickerTests 8/8 通过、0失败/跳过（/tmp/Maccy-history-drag-source-tests.xcresult）。既有预览动画间歇失败本次未复现，未经修复，不能因此关闭。39项候选 /tmp/Maccy-presets-history-drag-candidate.json SHA256 a8998f069744c3f5a14544477a8a3b1c1ea5f412d4ced626a2177a3b6185c343。新验收应用已按原路径更新，CDHash 2514141ef3adeee61606c961692ef614172d7ddd，签名要求与前版相同、沙箱有效；PID32915已实际打开独立数据库。应用备份 /tmp/Maccy-history-drag-app-backup-20260906-1028。自动化复制合成文本后未在历史搜索命中，真实拖放与保存验收仍待用户鼠标反馈；不把原生属性测试等同live通过。正式Maccy未运行，本轮未变更生产采集偏好；未提交、集成或推送。

2026-09-06T10:33:28.385635+08:00：拖放验收补充：主控直接只读SQLite核对，合成标题和UTF-8正文各精确匹配1条，SHA256 94a4c45ea57e332b24e190b67048039faf2fdf01442105b8bbf49f4c1e8b4fb8，确认已采集。AX搜索控件显示该查询但列表未显示；实际鼠标/键盘补验时窗口已关闭（noWindowsAvailable），停止UI重试，等待用户已发出的真人拖放反馈。尚未证明AX set_value触发了应用搜索绑定，不据此新增采集或搜索故障修复。未执行真实成功拖放，AC05仍待验；不要再次复制同一素材。

2026-09-06T10:51:52.345501+08:00：用户更新后再次报告失败，明确“出现条目拖影，但分组没有新增”。主控核验该时正在运行的是新版PID32915/CDHash2514141e…，不是未重启；退出按钮实际仅位于历史页，预设页未提供。AC05仍失败。为定位接收/保存环节，仅在 /tmp/Maccy-drag-diagnostic-source-20260906 临时源码副本的 HistoryDragSource.swift、AppState+Presets.swift 增加DEBUG阶段日志（无标题、正文、分组名、路径或token），不改变判定次数、返回值与存储流程；此为已授权取证，不追加功能修复或重置原plan/delivery=2/2及人工追加3轮。诊断独立审查SHIP，build/test8/8通过。诊断manifest a1cc98b8b668fac4f69ada4363113eaeef50c9b48bb2682f6f2de2694eaf0f25。已备份当前功能应用 /tmp/Maccy-drag-diagnostic-original-20260906/Maccy Presets QA.app 并临时载入同签名诊断版CDHash9090fddaf10542c89568ebfe86845613cc009450、PID52322、独立DB正常；mapped debug dylib与构建实际一致。历史日志未读到GUI初始化标记，尚不能证明目标未挂载，已开启5分钟、仅指定PID与诊断前缀的实时log读取 /tmp/Maccy-drag-probe-live.log，等待用户一次合成条目拖放，以source_session_start作通道正向证据。取证完成后恢复上述功能应用并移除临时副本/日志；具体根因修复另按规则形成方案。冻结功能候选39项a8998f…完全未改。

2026-09-06T11:05:46.339913+08:00：用户进一步确认目标区域没有高亮（本任务user436410009，2026-09-06T02:56:35Z）。原系统日志通道无有效GUI记录且5分钟窗口与操作未可靠对齐，不能据无日志判断回调。仍仅修改临时诊断副本两文件，增加own Caches中0600阶段文件与popup_begin必达标记；独立增量审查SHIP。最终单次回归7/8通过，唯一失败为既有窗口动画testPreviewAnimationAndHeightChangesKeepOneWindowFrame:94，850≠450；保留原断言、未重复测试、未修改动画，功能交付仍未通过。新诊断manifest e946cd66786e91c587bea841275f7605b0e614a760b77a725746fae8f6084842，CDHash92359fa0f3645544d53d1d1f1f1015659f57732d，当前PID65296，同签名/沙箱身份。实际读取 /Users/kinso/Library/Containers/org.kinsolee.Maccy.PresetsGUI202609052357/Data/Library/Caches/MaccyDragProbe-65296.log 已有popup_begin、loaded target_registered、target_layout positive_bounds=true，日志通道和原生目标挂载已正向确认。现等待一次真人合成条目拖动；记录持久至取证完成，无时间窗口限制。原功能应用备份251版仍在 /tmp/Maccy-drag-diagnostic-original-20260906/Maccy Presets QA.app，诊断后恢复；冻结39项a899完全未改。


2026-09-06T11:53:52.785478+08:00：用户再报无法拖入后，几何日志已确认鼠标进入当前目标（bounds/visible=true、hit=target、type/registration/同窗口正确、窗口未变）仍无接收回调；已停止相同几何重试。原生宿主接收方案经独立审查PASS，在原目标授权内实施drop-host-v1：仅HistoryDragSource.swift新增窄NSHostingView子类接收private type，按当前目标转发原NSDraggingInfo及原token/model校验；FloatingPanel仅替换host构造；1项命名剪贴板单元回归验证foreign source/noncopy拒绝和原无效token拒绝。其余36项候选未改。编译修正测试override后，最终测试构建通过；单次9项8通过/1失败，旧预览测试本次line106宽490而期望450，保留证据和断言，不称9/9。证据/tmp/Maccy-drop-host-tests.xcresult、-summary.json；最终增量审查SHIP。冻结39项/tmp/Maccy-presets-drop-host-candidate.json SHA256 5f23b979a6301e66f13eb83431c3e6b66b3e4a2bb3cd1663e3b78e4350d71821。
GUI候选增加临时DEBUG阶段记录，正式源码无日志；签名和原指定要求一致，实际PID6058/CDHash9f23707fad08f558b5dfa29b8d1a05e97dcc78fe，同路径启动已读回loaded host_registered及target挂载。尚未取得host_enter/保存正向结果，已请用户在新候选拖一次；AC05仍待验。取证后须移除诊断并用最终功能版替换或恢复原251功能备份，不能把宿主注册当live拖放成功。生产偏好未改、根代理没有本轮业务拖放/复制数据写入；源码未提交/合并/推送。修正计数delivery由2增为3，历史额外人工修复3轮原样保留，不因新版规则清零。
