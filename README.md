# Know_You（知颐）

基于 Flutter 开发的家庭守护与社区生活应用，聚焦长辈友好交互、亲情连接与日常辅助能力。

## 核心功能

- **账号与身份**：注册、登录、个人信息管理
- **亲情守护**：家庭绑定、健康数据同步、设备与日程相关能力
- **社区生活**：动态发布/评论/点赞、树洞、商品浏览与发布
- **语音辅助**：语音唤醒、语音识别、语音交互入口
- **无障碍朗读**：悬浮球 + 文本朗读能力（依赖系统无障碍与 TTS）
- **通讯与应用视图**：通讯录、应用列表及详情页面

## 技术栈

- Flutter / Dart
- Provider（状态管理）
- Dio（网络请求）
- WebSocket（实时通信）
- speech_to_text / flutter_tts（语音能力）

## 项目结构

```text
lib/
├── common/      # 配置、网络、服务与业务基础能力
├── pages/       # 页面模块（主页、社区、亲情守护、我的等）
└── widgets/     # 通用组件与语音/悬浮层组件
assets/
└── config/      # API、天气等前端配置
```

## 快速开始

### 1) 环境要求

- Flutter 3.x
- Dart 3.x
- Android Studio / Xcode（按目标平台安装）

### 2) 安装依赖

```bash
flutter pub get
```

### 3) 配置后端地址

编辑：`/home/runner/work/Know_You/Know_You/assets/config/api_config.json`

至少确认以下字段符合你的本地或测试环境：

- `api_base_url`
- `http_base_url`
- `ws_url`
- `asr_base_url`（如启用云端语音识别）
- `agent_api_url`（如启用 Agent 能力）

### 4) 运行应用

```bash
flutter run
```

## 权限与平台说明

项目包含语音识别、录音、联系人、定位、文件与悬浮相关能力，首次运行时会申请系统权限。
部分能力（如无障碍朗读、TTS）需在系统设置中手动启用或安装对应引擎。

## 开发状态

项目处于持续开发中，接口与页面细节可能调整。

## 第三方开源组件与协议说明

项目当前用到的重点第三方组件（以仓库内配置为准）：

- `flutter_webrtc`（`pubspec.yaml`）及其相关 WebRTC 组件
- `dev.rikka.shizuku:api`、`dev.rikka.shizuku:provider`（`android/app/build.gradle.kts`）

这些组件通常采用宽松协议（如 MIT / BSD / Apache-2.0）发布，一般不会强制你把项目改成同类开源协议；但你仍需遵守各自许可证义务，至少包括：

- 在发行版或仓库中保留第三方版权与许可证声明
- 不移除上游要求保留的 NOTICE / LICENSE 信息（如有）
- 关注你后续新增依赖是否引入更严格的 copyleft 约束

## 开源协议

本项目采用 **MIT License**，详见 `/home/runner/work/Know_You/Know_You/LICENSE`。
