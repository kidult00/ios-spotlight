好的，我已经仔细阅读了您的 `requirement.md` 文件，并结合您现有的项目结构，为您规划了以下项目开发方案：

## 一、项目结构建议

我们将在您现有的 `spotlight` 源码文件夹内进行组织，建议结构如下：

```
/Users/bytedance/W/project/mobile_hotspot/spotlight/
spotlight/
├── AR/                             # 新建: ARKit 相关逻
辑
│   ├── ARTrackingManager.swift     # 新建: 管理 
ARSession、面部追踪、眼部数据提取
│   └── GazePointConverter.swift  # 新建: 3D 注视点到 
2D 屏幕坐标转换逻辑 (或将逻辑合并到 ARTrackingManager)
├── Heatmap/                        # 新建: 热图相关逻辑
│   ├── HeatmapManager.swift      # 新建: 管理热图数据（注
视点统计）
│   └── HeatmapOverlayView.swift  # 新建: SwiftUI 视图，
用于渲染热图
├── UI/                             # 新建: 其他UI辅助组
件
│   └── ARViewContainer.swift     # 新建: 
UIViewRepresentable, 用于将 ARSCNView 或 ARView 嵌入 
SwiftUI
├── ContentView.swift             # 现有: (需要修改) 主视
图，将集成 AR 视图和热图覆盖层
├── spotlightApp.swift            # 现有: App 入口点，基
本无需修改
├── Assets.xcassets/                # 现有: 应用资源文件
└── Info.plist                      # (项目配置的一部分, 
需要修改) 应用配置文件，添加摄像头权限描述
```

## 二、核心开发步骤

1. 环境配置与权限设置:

   - 确保项目中已正确链接 ARKit 框架。
   - 修改项目的 Info.plist 文件：添加键 NSCameraUsageDescription (Privacy - Camera Usage Description)，其值为向用户解释为何需要摄像头权限的字符串，例如："此 App 需要访问您的摄像头以进行实时视线追踪和生成屏幕注视热区图。"

2. ARKit 面部追踪实现 (创建 `ARTrackingManager.swift` ):

   - 创建一个 ARTrackingManager 类，负责初始化 ARSession 并配置 ARFaceTrackingConfiguration 。
   - 让此类遵循 ARSessionDelegate 协议，并在 session(\_:didUpdate:) 代理方法中获取 ARFaceAnchor 对象。
   - 从 ARFaceAnchor 中提取左右眼的变换矩阵 ( leftEyeTransform , rightEyeTransform ) 以及头部姿态 ( headTransform )。

3. 注视点计算 (创建 `GazePointConverter.swift` 或集成到 ARTrackingManager ):

   - 根据提取到的眼部 3D 位置数据，计算用户的注视方向。
   - 将 3D 空间中的注视点（或视线与虚拟屏幕的交点）投影到 2D 屏幕坐标。这可以利用 ARSCNView (若使用 SceneKit) 或 ARView (若使用 RealityKit) 的 projectPoint(\_:) 方法。

4. 热图数据管理 (创建 `HeatmapManager.swift` ):

   - 设计一个 HeatmapManager 类来处理热图数据。
   - 内部使用一个数据结构（例如，一个二维数组或字典）来存储屏幕上不同区域的注视点累积频率或时长。
   - 提供方法来接收新的注视点坐标，并更新热图数据。

5. AR 视图集成 (创建 `ARViewContainer.swift` 并修改 `ContentView.swift` ):

   - 创建 ARViewContainer ，它是一个遵循 UIViewRepresentable (用于 UIKit 视图如 ARSCNView ) 或 UIViewControllerRepresentable 的 SwiftUI 结构体。这个容器将负责展示 AR 内容（摄像头画面）。
   - 在 `ContentView.swift` 中，使用 ARViewContainer 来嵌入 AR 视图。
   - 将 ARTrackingManager 的实例与 ARViewContainer 关联，以便启动和管理 AR 会话。

6. 热图可视化 (创建 `HeatmapOverlayView.swift` 并修改 `ContentView.swift` ):

   - 创建 HeatmapOverlayView ，这是一个 SwiftUI 视图，它将作为覆盖层绘制在 AR 视图之上。
   - HeatmapOverlayView 从 HeatmapManager 获取处理后的热图数据（例如，各区域的强度值）。
   - 使用 SwiftUI 的绘图能力 (如 Canvas ) 或结合 Core Graphics (通过 draw(rect:) 在 UIViewRepresentable 包装的自定义 UIView 中) 来渲染热图。根据需求文档，可以考虑使用 CIImage 结合高斯模糊滤镜生成热图图像，然后显示。

7. 主视图整合 (修改 `ContentView.swift` ):

   - 在 ContentView 中实例化并管理 ARTrackingManager 和 HeatmapManager 的生命周期。
   - 建立数据流： ARTrackingManager 获取眼部数据 -> GazePointConverter 计算屏幕坐标 -> HeatmapManager 累积数据。
   - 使用 ZStack 将 ARViewContainer 和 HeatmapOverlayView 叠放，确保热图正确显示在 AR 内容之上。

## 三、关键文件摘要

- 新建文件:
  - `ARTrackingManager.swift`
  - `GazePointConverter.swift`
  - `HeatmapManager.swift`
  - `HeatmapOverlayView.swift`
  - `ARViewContainer.swift`
- 修改文件:
  - `ContentView.swift` (主要集成和协调逻辑)
  - Info.plist (添加摄像头权限)

## 四、后续步骤建议

1. 起步：ARKit 基础与权限。 首先完成 Info.plist 的修改，然后搭建 ARTrackingManager 和 ARViewContainer 的基础框架，确保能启动 ARSession 并看到摄像头预览。
2. 核心：眼动追踪与坐标转换。 实现从 ARFaceAnchor 提取眼部数据，并将其转换为屏幕坐标。可以在屏幕上用一个简单的点来可视化追踪结果，进行调试。
3. 数据：热图数据模型。 开发 HeatmapManager ，实现注视点数据的收集和统计逻辑。
4. 呈现：热图可视化。 实现 HeatmapOverlayView ，根据 HeatmapManager 的数据绘制热图。
5. 优化与扩展： 根据 `requirement.md` 中的“关键挑战与解决方案”和“扩展功能建议”，逐步进行性能优化（如异步处理、Metal 加速）、加入校准机制等。
   这个规划为您提供了一个结构化的开发蓝图。在实际开发过程中，您可以根据具体情况灵活调整。祝您项目顺利！
