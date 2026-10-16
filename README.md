# blux — K.I.T.T. Cockpit

个人助理 App（仅 Android），按《霹雳游侠》KITT 风格重构：
开机扫描红光灯扫掠动画 + 汽车仪表盘式模块布局。

## 功能分区（本地 vs 服务器）

所有能自己闭环的数据都存在本机 SQLite（`kitt_blux.db`，见 `lib/local/local_db.dart`），
**无服务器也可完整使用**。只有媒体和硬件控制必须走原有服务器接口。

### 本地存储（离线可用）

| 模块 | 页面 | 说明 |
| --- | --- | --- |
| 每日任务 | `task_layer.dart` | 打卡记录存 `task_marks`，日期滚轮选日 |
| 任务类型配置 | `taskTypeSetting.dart` | 名称/权重/classify(body·soul·steps)/排序，存 `task_types`（首次运行自动种子数据） |
| 习惯打卡 | `habits.dart` + `month_grid.dart` | 六边形年度矩阵，存 `habit_types` / `habit_records` |
| 广告日志 | `ads.dart` + `local/ad_notify.dart` | 游戏/设备快捷名录（`ad_games`/`ad_phones`）+ 广告名手输 + 时间戳存 `ad_logs`；近14天柱图；每日固定时间本地通知，通知自带“推迟1小时/3小时” |
| 数据分析 (Billboard) | `billboard.dart` | 贡献热力图、本月/上月对比、Soul-Steps 跷跷板、运动冷却提醒 —— 全部由本地 SQL 聚合 |
| 屏幕使用统计 | `usage/usage_page.dart` | `recordPhoneUsage` 经 usage_stats 采集后直接写本地 `usage_daily`，不再上传服务器 |
| 使用时间线 | `usage/timeline.dart` | 直接查询系统 usage_stats，本来就离线 |
| 应用追踪设置 | `usage/edit_app.dart` | 显隐/重命名，存 `usage_apps` |

### 保留服务器接口（无法离线）

| 模块 | 依赖 | 原因 |
| --- | --- | --- |
| 视频清单 / 播放 (`videoList`, `video`) | PC 媒体服务 `host:9999` / `mediaHost:9998` | 片源在 PC |
| 听力练习 (`audios`) | `laravel audios` + mediaHost 流 | 音频文件在 PC |
| 登月图 (`moon`) | `Domain/storage/*.png` | 贴图素材在服务器 |
| 中继节点 (`v2ray`) | OpenWrt `192.168.0.1:89` + `host/v2ray/*` | 路由器控制 |
| 星空连线 (`stars`) | `wsHost` websocket | 联机玩法 |
| PC 唤醒 / 关机 | Wake-on-LAN 广播 + `host/shutdown` | 局域网硬件 |

链接地址可在抽屉（控制台）里修改，改完 `resetClients()` 会重建全部在线 Dio 客户端。
离线时首页对应磁贴显示 `LINK REQ` 并禁用。

## 视觉体系

- 界面文案已整体汉化（保留 K.I.T.T. / PC / body·soul·steps 等少量符号词），字号上调保证黑底可读
- `lib/kitt/theme.dart` — 配色（近黑座舱 + KITT 红 + 琥珀仪表色）、等宽字体主题
- `lib/kitt/widgets.dart` — `KittScanner`（LED 点阵扫描灯，逐颗亮灭+光晕）、`KittPanel`（切角仪表面板）、`KittGauge`（环形仪表）、`KittTile`、`BlinkDot`、`GridBackdrop`（座舱网格背景）
- `lib/kitt/splash.dart` — 开机自检序列：KITT 徽标 + 扫描灯左右扫掠 + 模块上线列表，完成后进座舱首页
- 窄屏溢出修复：仪表盘三联表按 LayoutBuilder 自适应、当日Top饼区、跷跷板图等均以可用宽度钳制

## 问题备忘

when problem : AAPT: error: resource android:attr/lStar not found.
    compileSdkVersion 31
