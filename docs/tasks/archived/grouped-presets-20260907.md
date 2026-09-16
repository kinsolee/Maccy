# grouped-presets：分组预设与统一选择窗口

- 身份：`grouped-presets`；主控及模块承载于现有任务 `01a071aa-e39d-7fa3-bc2a-14cfddc16d8e`，不新建用户侧任务。
- 工作位置：`local` / `kinsoleedeMacBook-Pro.local`；`/Users/kinso/code/github/kinsolee/Maccy-worktrees/grouped-presets`；分支 `codex/grouped-presets`；当前唯一 writer `/root`；独立 CLI 已冻结并退出，同一时间仅一位 writer。
- 权威索引：[INDEX.md](/Users/kinso/code/github/kinsolee/Maccy/docs/tasks/INDEX.md)。本卡仅实施 writer 写，修正计数仅以权威索引为准。
- 执行基线：`c376789c5d377b7c520b6f6e91f3f3a1aa28640b`；遵守索引列明的全局规则、Skill 指纹和四份未提交架构文档指纹；实施树已核验相同内容。
- 已批准：ADR-001、contract revision 2；2026-09-05 架构“确认”，23:07:25 +08:00 “UI用第 1 张作为任务目标”。UI 文件在 project-context.md，SHA256 `39283aeec9d9bd7c1bcfed5b1869608a29c8f8cca4e5daaf0600ca8929d09470`。
- 目标：顶部历史/预设分组统一入口，记忆明确选组；历史拖到组保存副本；就地新增/编辑/删除，无标题，按完整内容搜索；图片和文件独立保存。
- 文件归属：`Maccy/` 内相关存储、模型、视图、导航、搜索和剪贴板；`MaccyTests/`、相关测试配置及 `Maccy.xcodeproj/project.pbxproj`；完成后 README 对应能力说明；本卡。架构合同与权威索引由主控串行维护。无关代码、用户全局配置禁止修改。
- 保留约束：同一 FloatingPanel、热键、数据库和已装依赖；预设独立生命周期；保留历史固定项与复制/粘贴偏好。普通管理和拖放不写剪贴板。文件源永不删除。
- 不做：新依赖、另一个管理窗口、云同步、标题、跨组搜索、组间拖放排序、视频片段、文件自动回收。

## 验收与位置

| 编号 | 预期行为与方法 | 验证位置 / 人员 | 当前结果 |
| --- | --- | --- | --- |
| AC-01 | 新模型旧库兼容，合成历史/固定项不丢失；临时磁盘关闭重开验证 | 合并前；local；由本树编译，实际数据在 XCTest 独立 UUID 临时目录；/root 执行并判定 | 合成磁盘 / unit verified，通过 |
| AC-02 | 删除非空组保留未分组内容；历史 clear/clearAll 不影响预设；保存失败回滚不被其他上下文保存带入 | 同 AC-01；隔离单元/磁盘集成检查 | 合成磁盘 / unit verified，通过 |
| AC-03 | Xcode 构建通过；测试宿主不启动采集器/面板/迁移，测试使用隔离 Defaults/数据库/命名剪贴板 | 合并前；local；DerivedData `/tmp/Maccy-grouped-presets-build`；实际测试进程与临时目录单独核验；/root | 构建及隔离宿主断言通过 |
| AC-04 | UI 1 一窗管理、组恢复和单选；IME/过滤/删除不误发；与参考图相同状态比较 | 合并前；local；独立测试应用身份/位置待构建后核验；/root 操作，用户最终视觉验收 | 待完成，见当前检查点 |
| AC-05 | 拖放一次保存且留在历史，重复/取消/失效回调不发送；全文尾部/Unicode 搜索高亮正确 | 合并前；local；隔离测试及独立测试应用；/root | 待完成，见当前检查点 |
| AC-06 | 合成文本到 TextEdit/受控 Chrome；图片到支持图片的应用；文件到 Finder，源删除后仍可用并核对哈希；错误/取消无半成品 | 合并前；local；受控窗口、合成文件及独立应用身份待核验；/root；这是 live verified，不能用单元结果替代 | 待完成，见当前检查点 |
| AC-07 | 最终实际差异与新增文件接受独立只读审查，候选冻结并完成必要人工验收 | 当前实施工作树 + 独立验收位置；审阅者待派，/root 读回，用户确认视觉 | 待完成，见当前检查点 |

## 操作与交付边界

禁止提交、合并提交和推送；暂不修改生产应用、用户历史库、真实剪贴板或全局配置。编译不等于运行验收。启动独立测试应用前核验身份与存储/偏好隔离；系统输入、设备、窗口与剪贴板由 `/root` 唯一操作。无外部业务写入。合并后验收未安排，因为 Git 集成授权尚未提供。

## 当前检查点

2026-09-05 23:31:38 +08:00：里程碑 1 已实现并构建通过，PresetLibraryTests 5 passed / 0 failed / 0 skipped，见 `/tmp/Maccy-presets-storage-final.xcresult` 和 `/tmp/Maccy-presets-storage-final.log`。AC-01/02 的合成磁盘/单元检查及 AC-03 构建/隔离宿主检查已通过，未做生产库迁移或真实粘贴。失败注入在 context.save 前抛出；回滚后原模型关系仍带草稿的问题已修复为新私有 context 读回，保留草稿且仍抛原错误。

测试命令：Debug、`CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=org.kinsolee.Maccy.PresetsTests`、DerivedData `/tmp/Maccy-grouped-presets-build` 的 build-for-testing；随后 test-without-building 使用 `/tmp/Maccy-grouped-presets-build/Build/Products/Maccy-single-pass.xctestrun`、`-only-testing:MaccyTests/PresetLibraryTests -parallel-testing-enabled NO`。临时 xctestrun 仅去除默认 TestRepetitionPolicy，避免自动重试掩盖首次结果；未改变项目重试配置。测试数据位于系统临时目录 `MaccyPresetTests-<pid>/<UUID>`，宿主退出后由主控清理。

里程碑 2–4 已由独立 CLI 实现首个源码候选，现回到主控完成编译、回归和必要修复。初始内容指纹在 `/tmp/Maccy-storage-checkpoint-hashes.json`，实际差异以本树读回为准。主控负责最终独立审查、真实应用操作、视觉验收和集成。

交付尚未到达：代码候选已冻结且独立代码审查通过；人工视觉和完整跨应用验收仍缺，未部署或集成。当前仅主控 writer。

2026-09-05 23:45 +08:00：接单核验 cwd/root/branch/HEAD、现有 diff/新增文件及 Skill SHA256 均匹配。已读取 revision 2、ADR-001 与实施计划，UI 1 图像指纹匹配。保留存储失败回滚和 5 项断言；新增代码由本 writer 单独写入。只读搜索探索确认 Fuse 位置罚分也会漏正文尾部，搜索快照需覆盖完整正文和原有 alias/OCR。发送入口将统一捕获 generation/target/flags。未运行正常应用或触碰共享桌面/通用剪贴板。

2026-09-05 23:50:35 +08:00：里程碑 2–4 首个完整源码候选已冻结用于编译反馈，位置 `/tmp/Maccy-grouped-presets-ui-candidate-20260905-2350`，逐文件哈希 `source-hashes.json`，当前已跟踪差异 `/tmp/Maccy-presets-ui-candidate-2350.patch`。原工作树由本 writer 保留，未提交。

已写：同窗分组/无标题值草稿/就地新增编辑删除与脏草稿三选项、显式目标和延迟发送校验、AppKit 内部 token 拖拽生命周期、全文匹配与同源摘要、独立附件暂存/落位/回滚、类型化剪贴板入口、目标窗口与权限前置判断、中文/英文文案。新增 PresetPickerTests 4 项、PresetMediaTests 3 项，SearchTests 新增 4 项；原 PresetLibraryTests 5 项原断言保留。源码解析、pbxproj/strings 格式和 diff whitespace 检查通过；未运行新增单测。

构建环境阻塞：第一次 exit 74 为用户缓存不可写；重定位 ModuleCache 后第二次 exit 74 为 Foundation manifest 缓存；重定位 CFFIXED_USER_HOME 后第三次 exit 74 为 `sandbox-exec: sandbox_apply: Operation not permitted`。日志 `/tmp/Maccy-presets-ui-build.log`、`/tmp/Maccy-presets-ui-build-recovery.log`、`/tmp/Maccy-presets-ui-build-isolated.log`。只读 self_healing_diagnostician 已确认嵌套沙盒限制，没有已核验的不改变安全边界本地重试路径，停止重试；需主控在已有授权环境编译冻结副本并回传诊断。不能将旧 xcresult 用作本候选验证。

编译命令仍为 Debug、`CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=org.kinsolee.Maccy.PresetsUITestHost`、独立 DerivedData `/tmp/Maccy-grouped-presets-ui-build`、scheme Maccy `build-for-testing`；可从上述快照构建，不写实施树。AC-04/05/06 代码待编译和隔离测试，全部 live 项继续仅主控负责。writer 暂停应用源码写入，等待主控编译反馈后只修复必要问题；这不是独立交付评审，不改变权威计数。

## 最新检查点（2026-09-06）

- 用户00:36明确“允许”，批准人工追加第1轮窗口修复；plan=2、delivery=2保留。本轮已完成并冻结，不是无限新增修正额度。
- 最终39项代码清单 `/tmp/Maccy-presets-window-final-candidate.json` SHA256 `29179423e9d2decef25b7b56983610c8224508541ee2969c955bec8f47e6632b`；57 passed / 0 failed / 0 skipped，`/tmp/Maccy-presets-window-final-regression.xcresult`与-summary.json；最终受影响补审SHIP，主控读回哈希一致。
- AC-04部分live verified：新组、正文编辑、脏稿取消/放弃、组恢复、全文预览、搜索命中；本轮编辑450×379、列表450×295，400右空白已消失。详见 `design-qa.md` 和 comparison-fixed.html。仍缺IME、循环/菜单交叉及用户视觉确认。
- AC-05 unit verified，真实尾部命中可见；两种自动输入工具的拖放均未成功新增。本轮点击后恢复，未据此断言产品缺陷；需要用户真实鼠标投放验证。
- AC-06部分live verified：原文本在TextEdit/Edge手动粘贴读回完整；原txt源移走后Finder回贴哈希一致。新增视频：原生选择导入、移走导入源、从预设复制后Finder手工回贴，SHA256 `5b691853429d430e99a34f342e9e916d5e8cf9808b2c85c86a04b2774b1eeba9`、2246字节一致，证据fixture目录video-import-readback.json。图片类型和多文件live尚缺。
- 本轮用户批准辅助功能并完成系统验证，精确添加测试app后实际进程已通过权限检查；Option+Return触发目标窗口改变保护，空白TextEdit未被写入。等待用户从目标窗口亲自打开验收Maccy并按Option+Return，再由主控读回。缺权限提示和Only Copy已验证，手工Cmd+V不算自动粘贴。
- AC-07代码部分通过；非阻断旧P2队列暂停错位留待后续范围。未提交、合并、推送或部署生产应用；原集成树应用代码未改。
- 验收应用 `/tmp/Maccy-presets-gui-20260905-2357/Build/Products/Debug/Maccy.app`，bundle `org.kinsolee.Maccy.PresetsGUI202609052357`，本轮PID28620；严格签名、sandbox entitlement和实际独立容器SQLite已读回。主控唯一writer和共享桌面操作者。

## 待人工补验

1. 在独立验收应用的历史中，把262×320合成狗图片拖到“客服话术”，观察目标高亮；释放后应留在历史、分组恰好新增一条图片、所有控件恢复；再复制到支持图片的本地编辑器。
2. 允许并完成辅助功能授权后，用合成文本从原始目标窗口打开验收应用，选预设按Option+Return，核对自动返回并只粘贴一次；切换到另一应用应阻止自动发送；同应用内部窗口切换按paste-recovery-v1不再校验。
3. 用中文输入法在搜索/编辑中确认候选词，确认Return仅提交输入法而不复制或粘贴；再验证两份文件同时导入和原始热键/菜单行为。
4. 查看修复后对照，确认UI 1视觉；未通过的具体项回本任务继续。Git提交/集成/推送仍需单独明确请求。

2026-09-06 01:07：采集隔离检查纠正：0045临时两键同true实际只忽略一次，应用自动归false；已按初始absent精确恢复。只读任务唯一附件路径核对发现1条合成视频生产历史，未删/改历史。后续0104备份后改为持续暂停（ignoreEvents=true、ignoreOnlyNextEvent=false），读回通过；等待当前人工触发粘贴期间保持，结束必须恢复。独立QA仍PID28620，TextEdit新增空白未命名文稿已准备；系统身份验证已完成，不需再次索要同一授权。

2026-09-06T01:10:32.556814+08:00：等待用户真实触发自动粘贴前结束本轮操作；0104两项生产偏好已恢复原始absent并读回。39项源码冻结哈希再核一致，开发和集成树diff whitespace检查通过。QA应用和专用空白TextEdit仍保留供人工验收；Edge比较页、Finder received窗口仅为本任务创建，验收后关闭。没有后台持续监控。下一次由主控继续发送合成内容前，需新备份并正确持续暂停采集；不得复用假定旧状态。

人工反馈续查：用户回复“我无法在搜索框输入”。root读取QA时搜索框可见、enabled、focused，定向普通n事件能显示n，但不代表用户物理键盘焦点正确。当前等待用户区分中文输入法、英文也失败或有字但不筛选。只读导航补查未发现当前菜单栏打开/普通无修饰字符吞键的新分支；不据此添加NSApp.activate，以免破坏原目标捕获。另发现独立P2：searchVisibility=duringSearch且空query时HeaderView不创建输入控件，可能无法接收第一个字符；当前QA该偏好absent沿默认always，且报障读回有可见框，不与当前故障混同。此P2暂未修复，代码仍为39项冻结版本；普通源码/测试检查不替代物理输入验收。


2026-09-06 自动粘贴根因与待裁决：用户确认输入已恢复；真人Option+Return仍被目标提示拦截。01:23:33.016的sandboxd真实日志精确命中QA PID28620，拒绝`mach-lookup com.apple.axserver (per-pid)`，堆栈落在PasteTarget.capture→focusedWindow→AXUIElementCopyAttributeValue。新增AX读取被现有App Sandbox拒绝，使window=nil；当前提示不能证明目标实际改变。脱敏证据为fixture目录paste-target-sandbox-denial.json，源日志SHA256 482d2e86213c2c9e700d35028fa608036f065188dfd84302219d28f75e13e037。无需再由用户重复原样粘贴或授权；源码仍为39项冻结候选，当前正向自动粘贴验收blocked。

待批准方案paste-recovery-v1：删除跨进程AX窗口读取，沿用原Maccy发键机制，并保留原前台应用在发送前/关闭后仍存活且位于前台的双检查、管理/拖放锁和generation。将唯一popup历史栈自动发键分支也接入同一应用检查，普通无popup Intent保留原行为与管理锁。更新中英文失败文案和合同说明。无需更改sandbox、权限、Clipboard发键实现或FloatingPanel。明确取消原方案对同应用内窗口身份的保证，必须用户批准这个取舍后实施。独立方案审查PASS只覆盖调整后的方案；不是旧合同通过。范围AppState+Presets.swift、History.swift、必要PresetPickerTests、两种Localizable.strings及已批准后对应说明。验收为原目标实际自动插入、跨应用切换拒绝、锁/过期回调无发送、权限不足仍可复制；同应用窗口切换限制如实标注。plan=2、delivery=2保持，本次尚未批准或实施。详见权威INDEX；本轮未操作GUI、剪贴板、生产偏好或用户历史。


paste-recovery-v1已获用户“批准”并实现：39项冻结清单/tmp/Maccy-presets-paste-recovery-candidate.json，SHA256 4927e4436dc40968fc42c582bc515dd8742efb4d14e9987069b9fa219fd6c742。独立受影响代码补审PASS；隔离测试构建和保留原沙箱的签名GUI构建均PASS。root已核验新进程72003和实际独立容器SQLite，原进程28620已停止。plan=2、delivery=2保留，本次为人工批准追加第2项修复。

回归实际为42项中41passed、1failed、0skipped；失败为未修改的快速预览往返测试closed状态仍为850宽。新PID判断、全部History/Clipboard和管理锁用例通过。首次失败保存在/tmp/Maccy-presets-paste-recovery-regression.xcresult及-summary.json；只读诊断确认没有本次paste改动进入动画路径的证据。全部构建结束后单独一次动画诊断通过，/tmp/Maccy-presets-paste-recovery-animation-diagnostic.xcresult；这只说明本次未复现，未修复根因，不覆盖首次失败。暂不扩修窗口。

自动粘贴等待用户从TextEdit LEFT|RIGHT文稿实际打开带分组栏的Maccy并按Option+Return；当前没有插入成功证据。生产采集临时持续暂停，备份fixture目录preference-backup-20260906-013649-paste-recovery，两键原始均absent；本轮末必须精确恢复。新运行收据为fixture目录paste-recovery-runtime-receipt.json。完整功能仍有真实拖放、图片、多文件、IME及最终视觉验收待完成。


本轮结束读回：013649生产采集备份的两项偏好均已精确恢复原始absent，restored.txt和runtime receipt已更新；39项代码指纹仍一致，开发/集成树diff检查通过。QA72003与LEFT|RIGHT文稿保留供用户实际验证；尚未收到自动插入结果。下次主控写入合成剪贴板前重新备份并持续暂停生产采集，不假定旧暂停仍有效。未提交、集成、推送或完成归档。


辅助功能环境恢复（当前入口更新）：用户仍被权限提示阻止。真实tccd日志明确旧ad-hoc cdhash要求校验新构建返回-67050；临时产物也无可解析的Launch Services注册，精确tccutil reset首先以-10814失败。单路径注册未改变空查询后，root备份原产物、停止QA72003，使用现有Apple Development身份原生重建签名（源码39项未变），并复制到独立`/Users/kinso/Applications/Maccy Presets QA.app`。新入口strict/deep签名验证通过、原sandbox entitlement保持，系统精确查询唯一返回该路径，随后仅此BID的Accessibility reset成功。新副本尚未启动/取得新授权，系统设置辅助功能页添加按钮已准备，等待即时确认；不能把reset成功当作已授权或已粘贴。来源fixture/accessibility-stale-signature.json，构建/tmp/Maccy-presets-stable-signing-build.log，旧完整备份/tmp/Maccy-qa-permission-backup-20260906-015229/Maccy.app。生产设置/历史本轮未写入，旧41/42加单项诊断结果及未解决窗口回归保持原结论。


2026-09-06 02:00 +08:00：用户于01:58:07明确“允许”为稳定签名验收版添加辅助功能。主控核验CDHash仍为385e48660acd26ced7813f4addaeb64e981d56b1及39项源码冻结后，点击系统设置的添加；系统停在触控ID或密码验证，尚未进入选应用或写入权限。已请用户在本机完成验证，不收集密码、不重复索要已有许可。当前验收app尚未启动，生产采集偏好沿013649恢复结果保持未改，未进行新剪贴板或业务数据操作。原41/42回归及窗口动画未解状态不变。


2026-09-06T09:00:33.032884+08:00：用户再次回复“好了”后，实际系统设置辅助功能列表已显示“Maccy Presets QA”且开关on；不重复添加。已启动稳定签名副本，精确进程PID55600确认。当前新阻塞为启动前App Sandbox等待：secinitd 08:56:45.302记录新development签名不在旧同BID测试容器ACL并正在请求确认；进程采样停在_libsecinit_appsandbox，尚未进入应用/SQLite初始化。主控精确日志已核验，脱敏证据fixture/stable-qa-container-confirmation.json，源SHA256 d46fe05034599f984f5801c9c6b06d8c039288032a4a649b35a69a5c02f29132。权限开关on不等于容器访问获准或自动粘贴成功。未继续重启、重签、reset或改容器。已询问用户是否看到对应原生弹窗。只读核验UserNotificationCenter宿主实际运行，但Computer Use对该系统组件返回安全禁止；停止该UI路径，等待用户在本机处理。确认后须读回实际独立SQLite路径再验收。没有本轮剪贴板写入，生产ignoreEvents/ignoreOnlyNextEvent仍为absent。源码39项不变、自动计数2/2和窗口问题仍保留。


2026-09-06T09:26:28.501294+08:00：用户反馈没有看到弹窗后，主控与只读诊断分别核验到同一PID55600已经打开独立QA容器的Storage.sqlite及wal/shm；原启动等待事实已解除，未重启、重签、reset或修改容器，授权如何完成未知。QA窗口真实可读且客服话术合成预设仍在。TextEdit已准备LEFT|RIGHT、光标位于|前，待用户从菜单栏打开QA并Option+Return实际插入；工具定向发键不能替代全局菜单/热键交互。生产采集两键已备份至fixture/preference-backup-20260906-092449-stable-live，持续暂停，本轮结束前须按原始absent恢复。辅助功能开关开启及数据库读回已通过，自动粘贴仍待验收。


2026-09-06T09:27:20.611399+08:00：本轮结束前092449生产采集偏好两键已恢复原始absent并读回，restored.txt已保存；QA55600与专用TextEdit文稿留待用户实际Option+Return验收。尚未取得本版本自动插入正向结果，未新增代码修改或测试通过声明。


2026-09-06T09:35:05.584854+08:00：用户09:33:18明确“可以插入”，在本任务Option+Return验收请求后确认自动插入成功，记录为自动粘贴人工确认通过，不再重复辅助功能授权。主控当前读到的TextEdit文稿仍是原合成基线，未取得该次具体正文及目标的独立读回，因此不扩大为完整文本一致性/跨应用保护/全部AC-06通过。收据fixture/automatic-paste-user-confirmation.json；39项源码指纹和开发/集成树diff检查通过。生产偏好沿092449已恢复状态保持未改。

待裁决的最小窗口修复preview-synchronous-frame-v1已由原独立评审者审查PASS，尚未批准/实施。仅修改SlideoutController.swift：取消250ms的异步SwiftUI/NSAnimationContext/window.animator帧动画和无用回调字段，复用当前尺寸/左右放置计算，同次setFrame；设置期间保留opening/closing防误保存尺寸，返回前即稳定open/closed。保留原顶边、管理锁、选择、自动打开延时及抑制行为，FloatingPanel/Popup无需行为改动。UI取舍为历史和预设的预览改成立即展开/收起。保留原失败测试的全部有效断言及等待，批准后重构建、单项及必需回归、实际可见窗口验证。plan=2/delivery=2保留，需新的具体人工裁决；原41/42结果不被方案审查替代。


2026-09-06T10:11:46.640596+08:00：用户报告Shift+Cmd+C先出现取色器、点击后Maccy才可见。只读核验QA实际快捷键carbonKeyCode=8、modifiers=768，即Shift+Command+C；本机BetterShot 0.4.3 PID82719同时运行，官方CHANGELOG将Pick Color默认定义为同一组合。独立代码检查确认本次未改全局绑定，首次keyDown立即打开，不等待鼠标点击。高置信度为外部取色快捷键冲突；未停用对照，精确事件先后未证实。建议保留Maccy组合、调整或关闭BetterShot的Pick Color快捷键；用户仅询问原因，本轮未修改设置/代码/进程。证据fixture/shortcut-conflict-diagnosis.json。预览同步修复方案仍未批准，不把此问当作批准。


2026-09-06T10:18:46.222334+08:00：用户已通过改键解决BetterShot冲突，另真人报告两个方向拖动均无效。历史→预设应保存副本且保留历史；已定位HistoryDragSource.DragView未覆盖mouseDownCanMoveWindow，原生无窗口AppKit探针实测透明NSView为true，与FloatingPanel背景拖窗存在路由冲突。候选history-drag-source-v1仅将源视图该属性覆盖为false，独立方案审查PASS；activeDrag不会提前移除/禁用源和目标，仍须缩略图/高亮/一次保存/取消解锁/剪贴板不变的真人验收。源码39项未改，未将候选当作已修复。预设→历史没有source或target，原批准范围未包含；已询问用户保留副本或移出语义，等待答复。plan=2/delivery=2保持，历史拖拽修复需具体追加裁决；同步预览方案仍未批准。证据fixture/drag-source-diagnosis.json。本轮仅只读与合成AppKit属性探针，未改应用设置、数据或通用剪贴板。

2026-09-06 10:21:47 +08:00：用户回复“允许”，批准 history-drag-source-v1 追加修复（本任务 user message 979515173）。独立方案评审 PASS；主控解除相关候选冻结，仅修改 HistoryDragSource.DragView 的 mouseDownCanMoveWindow 及一项原生属性回归。原 plan_fix_rounds=2、delivery_fix_rounds=2 保留，本次为人工追加第3轮。预设→历史语义及取消预览动画不在本次批准范围。

2026-09-06T10:31:23.793640+08:00：history-drag-source-v1 已实施：DragView 原生 mouseDownCanMoveWindow=false，并增加一项属性回归，其余鼠标/投放/结束处理不变。增量独立审查 SHIP；单次 PresetPickerTests 8/8 通过、0失败/跳过（/tmp/Maccy-history-drag-source-tests.xcresult）。既有预览动画间歇失败本次未复现，未经修复，不能因此关闭。39项候选 /tmp/Maccy-presets-history-drag-candidate.json SHA256 a8998f069744c3f5a14544477a8a3b1c1ea5f412d4ced626a2177a3b6185c343。新验收应用已按原路径更新，CDHash 2514141ef3adeee61606c961692ef614172d7ddd，签名要求与前版相同、沙箱有效；PID32915已实际打开独立数据库。应用备份 /tmp/Maccy-history-drag-app-backup-20260906-1028。自动化复制合成文本后未在历史搜索命中，真实拖放与保存验收仍待用户鼠标反馈；不把原生属性测试等同live通过。正式Maccy未运行，本轮未变更生产采集偏好；未提交、集成或推送。

2026-09-06T10:33:28.385635+08:00：拖放验收补充：主控直接只读SQLite核对，合成标题和UTF-8正文各精确匹配1条，SHA256 94a4c45ea57e332b24e190b67048039faf2fdf01442105b8bbf49f4c1e8b4fb8，确认已采集。AX搜索控件显示该查询但列表未显示；实际鼠标/键盘补验时窗口已关闭（noWindowsAvailable），停止UI重试，等待用户已发出的真人拖放反馈。尚未证明AX set_value触发了应用搜索绑定，不据此新增采集或搜索故障修复。未执行真实成功拖放，AC05仍待验；不要再次复制同一素材。

2026-09-06T10:51:52.345501+08:00：用户更新后再次报告失败，明确“出现条目拖影，但分组没有新增”。主控核验该时正在运行的是新版PID32915/CDHash2514141e…，不是未重启；退出按钮实际仅位于历史页，预设页未提供。AC05仍失败。为定位接收/保存环节，仅在 /tmp/Maccy-drag-diagnostic-source-20260906 临时源码副本的 HistoryDragSource.swift、AppState+Presets.swift 增加DEBUG阶段日志（无标题、正文、分组名、路径或token），不改变判定次数、返回值与存储流程；此为已授权取证，不追加功能修复或重置原plan/delivery=2/2及人工追加3轮。诊断独立审查SHIP，build/test8/8通过。诊断manifest a1cc98b8b668fac4f69ada4363113eaeef50c9b48bb2682f6f2de2694eaf0f25。已备份当前功能应用 /tmp/Maccy-drag-diagnostic-original-20260906/Maccy Presets QA.app 并临时载入同签名诊断版CDHash9090fddaf10542c89568ebfe86845613cc009450、PID52322、独立DB正常；mapped debug dylib与构建实际一致。历史日志未读到GUI初始化标记，尚不能证明目标未挂载，已开启5分钟、仅指定PID与诊断前缀的实时log读取 /tmp/Maccy-drag-probe-live.log，等待用户一次合成条目拖放，以source_session_start作通道正向证据。取证完成后恢复上述功能应用并移除临时副本/日志；具体根因修复另按规则形成方案。冻结功能候选39项a8998f…完全未改。

2026-09-06T11:05:46.339913+08:00：用户进一步确认目标区域没有高亮（本任务user436410009，2026-09-06T02:56:35Z）。原系统日志通道无有效GUI记录且5分钟窗口与操作未可靠对齐，不能据无日志判断回调。仍仅修改临时诊断副本两文件，增加own Caches中0600阶段文件与popup_begin必达标记；独立增量审查SHIP。最终单次回归7/8通过，唯一失败为既有窗口动画testPreviewAnimationAndHeightChangesKeepOneWindowFrame:94，850≠450；保留原断言、未重复测试、未修改动画，功能交付仍未通过。新诊断manifest e946cd66786e91c587bea841275f7605b0e614a760b77a725746fae8f6084842，CDHash92359fa0f3645544d53d1d1f1f1015659f57732d，当前PID65296，同签名/沙箱身份。实际读取 /Users/kinso/Library/Containers/org.kinsolee.Maccy.PresetsGUI202609052357/Data/Library/Caches/MaccyDragProbe-65296.log 已有popup_begin、loaded target_registered、target_layout positive_bounds=true，日志通道和原生目标挂载已正向确认。现等待一次真人合成条目拖动；记录持久至取证完成，无时间窗口限制。原功能应用备份251版仍在 /tmp/Maccy-drag-diagnostic-original-20260906/Maccy Presets QA.app，诊断后恢复；冻结39项a899完全未改。


2026-09-06T11:20:32.700375+08:00：真实文件回调已确认4次source_session_start→source_end(operation=0)，无target/model/import回调；证据drag-native-callbacks-65296.json/log，不能归因为保存。临时几何诊断仅增加源拖动回调中的当前鼠标位置、目标bounds/visibleRect/hidden/type及普通hitTest固定分类；使用SDK明确的session.draggingLocation，全部布尔元数据，正式39项a899不变。独立增量审查SHIP、最终GUI构建和strict/deep签名通过，指定要求与旧版一致；当前PID75888/CDHash922930c17776f83009a7725bf2b28241c9f6c104，实际loaded geometry_probe=true已读回，尚无本版drag move。主控UI筛选合成条目时中文输入不可靠，窗口随后noWindowsAvailable，未实际拖动；已请用户打开窗口拖一次，等待区分当前区域/分发问题。仅验证构建与运行加载，保留前次7/8和既有动画失败，不反复跑无关用例。证据fixture/drag-geometry-receipt.json；原功能251版恢复物仍保留，取证未完成故诊断版暂在运行。
本轮安装Skill路径已漂移至codex-task-management/0.1.2，实际重读SHA256 a765ebc76c19a522b3394aedd0bf5deb0d9e146d9486225f525deb228d2576bf。新版明确修正次数只用于诊断、不是推进配额，原目标内根因修复无需重复批准；plan=2/delivery=2、历史人工追加3轮原样留存，不再据旧配额暂停。逆向拖放语义与取消预览动画的既有待决策记录仍需分别处理。


2026-09-06T11:53:52.785478+08:00：用户再报无法拖入后，几何日志已确认鼠标进入当前目标（bounds/visible=true、hit=target、type/registration/同窗口正确、窗口未变）仍无接收回调；已停止相同几何重试。原生宿主接收方案经独立审查PASS，在原目标授权内实施drop-host-v1：仅HistoryDragSource.swift新增窄NSHostingView子类接收private type，按当前目标转发原NSDraggingInfo及原token/model校验；FloatingPanel仅替换host构造；1项命名剪贴板单元回归验证foreign source/noncopy拒绝和原无效token拒绝。其余36项候选未改。编译修正测试override后，最终测试构建通过；单次9项8通过/1失败，旧预览测试本次line106宽490而期望450，保留证据和断言，不称9/9。证据/tmp/Maccy-drop-host-tests.xcresult、-summary.json；最终增量审查SHIP。冻结39项/tmp/Maccy-presets-drop-host-candidate.json SHA256 5f23b979a6301e66f13eb83431c3e6b66b3e4a2bb3cd1663e3b78e4350d71821。
GUI候选增加临时DEBUG阶段记录，正式源码无日志；签名和原指定要求一致，实际PID6058/CDHash9f23707fad08f558b5dfa29b8d1a05e97dcc78fe，同路径启动已读回loaded host_registered及target挂载。尚未取得host_enter/保存正向结果，已请用户在新候选拖一次；AC05仍待验。取证后须移除诊断并用最终功能版替换或恢复原251功能备份，不能把宿主注册当live拖放成功。生产偏好未改、根代理没有本轮业务拖放/复制数据写入；源码未提交/合并/推送。修正计数delivery由2增为3，历史额外人工修复3轮原样保留，不因新版规则清零。

## 交付检查点(2026-09-07,ZCode 接手收尾)

- AC-05 live verified:用户真人拖放(历史条目→分组标签)成功保存、条目留在历史、控件恢复,用户明确确认"可以拖动了,也可以拖进去"。
- 拖放失败真根因(此前 drop-host/几何各轮探索均非要害):FloatingPanel 设置 `isFloatingPanel=true` 时窗口服务器不向该面板派发拖放目标事件。修复为移除该属性并将 level 从 `.screenSaver` 降为 `.modalPanel`(注释见 FloatingPanel.swift)。
- 间歇性 `testPreviewAnimationAndHeightChangesKeepOneWindowFrame` 失败根因修复:预览展开/收起改为单次同步 `setFrame`,移除 `window.animator()` 异步 completion 竞态(frame 生成计数、windowAnimationOrigin 等一并移除);`suspendSending` 简化。修复后该用例连跑 4 次通过。
- 2026-09-07 用户确认拖放后新增两项产品调整并已实施:
  1. 新分组排在标签栏最前(`PresetLibrary` groups 按 `createdAt` 降序),新增 `testNewGroupsLeadTheTabBar`;
  2. 删除即时生效、取消二次确认(预设可从历史重拖、组删除保留内容于未分组,无不可逆损失);移除 `pendingDeletion`/`confirmDeletion`、确认 UI 分支与两语文案,`requestDelete` 直接执行。
- 回归:单次运行(剔除 TestRepetitionPolicy)114 passed / 0 failed / 0 skipped,`/tmp/Maccy-final-regression2.log`。源码无任何遗留诊断日志;QA 应用为干净签名版(`/Users/kinso/Applications/Maccy Presets QA.app`,bundle `org.kinsolee.Maccy.PresetsGUI202609052357`,独立容器)。
- 教训记录:本轮曾用合成鼠标事件(CUA/CGEvent)定位拖放,干扰用户真实鼠标且 CUA 窗口绑定会令悬浮面板失焦自毁;GUI 验收一律由用户真人执行,自动化仅用 shell/AX 无副作用读回。
- 生产 Maccy、生产历史库与采集偏好未修改。本检查点后提交分支并合并 master(不推送远端)。

## 交付检查点二(2026-09-07,用户验收后四项调整)

用户确认拖放可用后提出四项问题,已全部实施:

1. **删除后不再强制跳选**:`refreshPresetResults(autoselect:)` 参数化;删除预设后清空选中而非自动选中第一项。顺带修复拖动移动后同样被 `selectPreset` 的 interactionLocked 守卫吞掉的问题(`drop()` 在刷新前先清 `activeDrag`)。
2. **预设跨分组拖动**:`HistoryDragSource` 泛化为 `.history/.preset` 两种源;预设行右侧新增拖动把手(≡,悬停显示),拖到其他分组标签即**移动**(重父级,`PresetLibrary.movePreset`);拖到"未分组"即移出分组。`canDropHistory/dropHistory` 更名 `canDrop/drop` 并按源类型分派。
3. **搜索框移至分组栏上方,全局搜索**:HeaderView 顺序调整;非空查询跨所有分组搜索,结果带所属分组名标签,清空查询回到当前分组列表;`send()` 移除"预设必须属于当前分组"守卫,全局搜索结果可直接发送。
4. **点击仅选中预览,修饰键+点击才发送**:预设行普通点击只选中并触发预览自动展开(`startAutoOpen`);按住 ⌘/⌥ 等修饰键点击按 `HistoryItemAction` 语义复制/粘贴。底部图例新增 "Click Preview" 与对应修饰键提示。历史行行为不变(原 Maccy 语义)。

回归:全量单次 **116 passed / 0 failed / 0 skipped**(113 原有 + 3 新增:`testNewGroupsLeadTheTabBar`、`testDeletingPresetDoesNotForceSelectAnotherRow`、`testPresetDragMovesGroupsAndSearchReachesAllGroups`)。动画用例的历史偶发失败定位为断言与窗口服务器帧应用时序的竞争(产品路径已是同步),断言改为帧稳定轮询后全量连续 3 轮通过。QA 应用已更新重启。已合并 master(不推送)。

## 交付检查点三(2026-09-07,第二轮用户反馈四项)

1. **面板出现在光标所在屏幕**:根因是前轮调试写入 QA 容器的偏好残留(`popupPosition=lastPosition`、`popupScreen=2`),已删除恢复默认 `.cursor`(产品逻辑本就按鼠标所在屏幕定位与约束)。
2. **拖入/移动的条目置顶**:分组内预设改为 `savedAt` 倒序;历史拖入的新预设天然在顶部,跨组移动时 `movePreset` 更新 `savedAt` 使其落在顶部。
3. **取消拖动把手,整行可拖**:预设行与历史行一致,整行覆盖 `HistoryDragSource`(点击语义不变:普通点击选中预览,修饰键点击发送);右侧省略号菜单保留。放宽 `beginPresetDrag`/`canDrop` 的分组限制,全局搜索结果跨组行也可拖动移动。
4. **预览记住最后开关状态**:新增 `Defaults[.previewOpen]`,`togglePreview` 写入,面板 `open()` 时按上次状态恢复(未锁定时);默认关闭(首次行为不变)。

回归:全量单次 **117 passed / 0 failed**(新增 `testHistoryDropLandsOnTopOfTheGroup`),连续两轮干净;HistoryItemTests 单独复跑 3/3(全量 run 1 曾有一次无关崩溃,复跑未现)。QA 应用已更新重启,调试偏好已清理。已合并 master(不推送)。



