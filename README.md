# Know\_You

基于 Flutter对uni-FamliyGuard项目的重构，部分功能还在持续完善开发中，后端暂未公开代码，服务暂未部署

## 功能架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                           知颐 APP                                  │
├──────────────┬──────────────┬──────────────┬──────────────┐         │
│    主页      │   社区生活    │   亲情守护    │     我的     │         │
│ IndexPage    │ CommunityPage│FamilyGuardPage│  MinePage    │         │
├──────────────┼──────────────┼──────────────┼──────────────┤         │
│ 健康数据同步 │ 树洞广场      │ 家人绑定      │ 用户管理      │         │
│ 天气信息     │ 颐养商城      │ 远程协助      │ 绑定码管理    │         │
│ 电话本       │ 商品推荐      │ 健康监护      │ 商品上架      │         │
│ 应用程序     │ 语音发帖      │ WebRTC屏幕控  │ 帖子管理      │         │
└──────────────┴──────────────┴──────────────┴──────────────┘         │
│                                                                     │
│                    核心服务层 (lib/common/)                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │
│  │ 语音助手    │ │ 悬浮球服务   │ │ WebRTC服务   │ │ Shizuku服务 │   │
│  │ 语音识别    │ │ 屏幕朗读     │ │ 远程控制     │ │ 无障碍保活   │   │
│  │ 唤醒词检测  │ │ TTS播报      │ │ 屏幕共享     │ │             │   │
│  │ Agent执行   │ │             │ │ 心跳保活     │ │             │   │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │
│  │ HTTP服务    │ │ 认证管理     │ │ 通知服务     │ │ 本地代理     │   │
│  │ API请求     │ │ Token刷新   │ │ 消息推送     │ │ LocalAgent  │   │
│  │ 拦截器      │ │ 登录状态     │ │ 导航跳转     │ │             │   │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## 核心功能模块

### 1. 健康管理

- **数据采集**：自动同步步数、睡眠时长、心率、血压等健康数据
- **健康插件**：集成自定义健康数据采集包 (`packages/health/`)
- **自动同步**：每10分钟自动同步设备健康数据至云端
- **天气信息**：基于GPS定位获取实时天气数据

### 2. 远程协助

- **WebRTC屏幕共享**：基于 WebRTC 实现实时屏幕远控
- **虚拟触控**：支持远程点击、滑动操作
- **导航控制**：返回、主页、最近应用快捷操作
- **安全防护**：支付风控检测，自动中断风险操作

### 3. 语音助手

- **语音识别**：支持本地语音识别与云端 ASR
- **唤醒词检测**：自定义唤醒词触发（默认："你好，牛肉"）
- **方言支持**：跨平台全场景方言识别
- **Agent执行**：语音指令驱动自动化操作

### 4. 屏幕朗读

- **悬浮球服务**：全局悬浮球，点击触发屏幕朗读
- **无障碍集成**：支持 Android 无障碍服务
- **TTS播报**：文字转语音，支持多语言
- **Shizuku保活**：通过 Shizuku 实现无障碍服务持久化

### 5. 社区社交

- **树洞广场**：图文/语音发帖、评论、点赞互动
- **颐养商城**：养老商品专属售卖、智能推荐
- **推荐系统**：基于用户画像的内容与商品推荐

### 6. 亲情守护

- **家人绑定**：绑定码机制实现家人关联
- **角色定义**：监护人/被监护人角色划分
- **健康监护**：实时查看家人健康数据与位置信息
- **状态同步**：实时同步家人设备状态

### 7. Agent与方言识别模块开发中



  <br />

  <br />

## 技术栈

| 类别        | 技术                                       |
| --------- | ---------------------------------------- |
| 框架        | Flutter 3.x                              |
| 状态管理      | Provider                                 |
| 网络请求      | Dio                                      |
| 屏幕适配      | flutter\_screenutil                      |
| WebRTC    | flutter\_webrtc                          |
| WebSocket | web\_socket\_channel                     |
| 语音识别      | <br />                                   |
| 语音合成      | flutter\_tts                             |
| 健康数据      | 自定义 health package                       |
| 地理定位      | geolocator                               |
| 权限管理      | permission\_handler                      |
| 图片处理      | image\_picker / flutter\_image\_compress |
| 本地存储      | shared\_preferences                      |
| 跨平台原生     | Shizuku / Android AIDL                   |

## 项目结构

```
Know_You/
├── lib/
│   ├── main.dart                  # 应用入口
│   ├── common/                    # 核心服务
│   │   ├── api.dart               # API接口定义
│   │   ├── http.dart              # HTTP服务与拦截器
│   │   ├── auth_provider.dart     # 认证状态管理
│   │   ├── voice_assistant_service.dart  # 语音助手
│   │   ├── floating_ball_service.dart    # 悬浮球服务
│   │   ├── webrtc_service.dart    # WebRTC远程协助
│   │   ├── shizuku_service.dart   # Shizuku服务
│   │   ├── notification_service.dart     # 通知服务
│   │   ├── agent/                 # 本地Agent
│   │   └── app_config.dart        # 应用配置
│   ├── pages/                     # 页面模块
│   │   ├── auth/                  # 登录/注册
│   │   ├── index/                 # 主页
│   │   ├── community/             # 社区生活
│   │   │   ├── tree_hole_page.dart    # 树洞广场
│   │   │   ├── mall_page.dart         # 颐养商城
│   │   │   └── post_detail_page.dart  # 帖子详情
│   │   ├── familyGuard/           # 亲情守护
│   │   ├── mine/                  # 个人中心
│   │   ├── phonebook/             # 电话本
│   │   └── programs/              # 应用程序
│   └── widgets/                   # 通用组件
│       ├── voice_assistant_dialog.dart   # 语音助手弹窗
│       ├── voice_assistant_overlay.dart  # 语音助手浮层
│       └── common_card.dart       # 通用卡片
├── android/                       # Android原生代码
│   └── app/src/main/
│       ├── kotlin/                # Kotlin服务
│       │   ├── FloatingBallService.kt       # 悬浮球服务
│       │   ├── RemoteControlAccessibilityService.kt  # 远程控制
│       │   ├── ScreenCaptureForegroundService.kt     # 录屏前台服务
│       │   ├── ShellService.kt    # Shell服务
│       │   └── ShizukuHelper.kt   # Shizuku辅助
│       └── aidl/                  # AIDL接口
├── ios/                           # iOS原生代码
├── packages/
│   └── health/                    # 健康数据采集包
├── assets/
│   ├── config/                    # 配置文件
│   ├── images/                    # 图片资源
│   └── diagrams/                  # 架构图
└── pubspec.yaml                   # 依赖配置
```

## API 接口

应用通过 RESTful API 与 Node.js 后端通信，支持以下模块：

- **认证模块**：注册、登录、Token刷新
- **绑定模块**：家人绑定、绑定码生成与使用
- **健康模块**：健康数据同步与查询
- **天气模块**：天气信息同步
- **设备模块**：IoT设备管理与控制
- **屏幕模块**：远程协助会话管理
- **日程模块**：日程管理
- **社区模块**：帖子、评论、点赞
- **商城模块**：商品、订单管理
- **推荐模块**：内容推荐、行为追踪

## 数据库表结构

项目包含22张核心数据表，涵盖用户、绑定关系、健康数据、社区、商城、推荐等模块，详细结构见 [数据库表结构汇总.md](file:///C:/Users/29449/Documents/Code/java/Know_You/数据库表结构汇总.md)。

## 开发环境

- **Flutter SDK**：>=3.0.0 <4.0.0
- **Dart SDK**：>=3.0.0
- **Gradle**：8.12（Android）
- **Flutter镜像**：<https://mirrors.tuna.tsinghua.edu.cn/flutter>

## 快速开始

```bash
# 克隆项目
git clone <repository-url>
cd Know_You

# 安装依赖
flutter pub get

# 运行项目
flutter run

# 构建 APK
flutter build apk

```

## 配置说明

API 配置文件位于 `assets/config/api_config.json`，包含：

- `apiBaseUrl`：后端 API 基础地址
- `asrBaseUrl`：语音识别服务地址
- 其他服务配置

## 注意事项

1. **无障碍服务**：远程协助和悬浮球功能需要启用无障碍服务
2. **麦克风权限**：语音助手需要麦克风权限
3. **Shizuku**：无障碍保活功能需要安装 Shizuku 服务
4. **语音引擎**：屏幕朗读需要安装 TTS 语音引擎（如 Google 文字转语音）
5. **API字段规范**：前端 API 请求/响应字段使用 snake\_case 格式

