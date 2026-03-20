# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

iOS 用户注视热区检测应用（spotlight），利用 TrueDepth 摄像头和 ARKit 实时追踪用户视线，在屏幕上映射注视热区。颜色越深表示注视概率越高。目标设备：iPhone X 及更新机型。

## 开发环境

- **设备**: 搭载 Apple 芯片的 Mac
- **IDE**: Xcode 16.3+（项目文件 `spotlight.xcodeproj`）
- **语言**: Swift 5.9+，SwiftUI + RealityKit
- **部署目标**: iOS 18.4+
- **所有沟通使用中文**

## 构建与运行

```bash
# 构建项目（模拟器）
xcodebuild -project spotlight.xcodeproj -target spotlight -sdk iphonesimulator build

# 运行测试
xcodebuild -project spotlight.xcodeproj -target spotlightTests -sdk iphonesimulator test

# 注意：面部追踪功能只能在真机（TrueDepth 摄像头）上测试，模拟器不支持 ARFaceTrackingConfiguration
```

## 架构

采用 SwiftUI + RealityKit，通过 `UIViewRepresentable` 桥接 RealityKit 的 `ARView`。使用 `@Observable`（Observation 框架）驱动 UI 更新。

```
ARSession → ARTrackingManager（@Observable，提取面部/眼部数据）
    → GazePointConverter（3D→2D 投影）
    → ContentView .onChange → HeatmapManager（网格累积 + CIImage 渲染）
    → HeatmapOverlayView（热图显示）
```

### AR 层 (`spotlight/AR/`)

- `ARTrackingManager` — @Observable 类，管理 ARSession 生命周期。ARSessionDelegate 回调在后台线程，通过 `DispatchQueue.main.async` 回主线程更新属性。30fps 节流控制。
- `GazePointConverter` — 无状态 struct。核心算法：双眼中点(世界坐标) → lookAtPoint(w=1 位置点变换到世界坐标) → 注视射线与虚拟平面交点 → ARCamera.projectPoint。虚拟平面距离根据人脸到摄像头实际距离动态计算。

### 热图层 (`spotlight/Heatmap/`)

- `HeatmapManager` — @Observable 类，二维网格（cellSize=10pt）存储注视权重，高斯分布叠加，10fps 节流生成热图图像。CIGaussianBlur + 放大到屏幕尺寸。颜色梯度：蓝→青→绿→黄→红。
- `HeatmapOverlayView` — 显示 HeatmapManager 的 heatmapImage（CGImage）。

### UI 层 (`spotlight/UI/`)

- `ARViewContainer` — `UIViewRepresentable` 包装 RealityKit `ARView`，仅接收 ARSession 引用。

### 主视图

- `ContentView` — ZStack 叠放：ARViewContainer → HeatmapOverlayView → 注视点指示器 → 控制面板（热图开关/重置按钮）。通过 `.onChange(of: gazeScreenPoint)` 将注视数据传递给 HeatmapManager。

## 关键技术细节

- 项目使用 `PBXFileSystemSynchronizedRootGroup`，新文件放入 `spotlight/` 目录后自动被 Xcode 识别
- `simd_float4.xyz` 扩展定义在 `GazePointConverter.swift` 底部
- `NSCameraUsageDescription` 已在构建设置中通过 `INFOPLIST_KEY` 配置（自动生成 Info.plist）
- ARSessionDelegate 回调运行在 ARKit 后台串行队列，所有 UI 属性更新必须 dispatch 到主线程
