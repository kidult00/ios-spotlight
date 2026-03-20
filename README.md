# Spotlight - iOS 注视热区检测

利用 TrueDepth 摄像头和 ARKit 实时追踪用户视线，在屏幕上生成注视热区图。颜色越深表示注视概率越高。

## 功能

- 基于 ARKit 面部追踪的实时视线检测
- 注视热区可视化（蓝→青→绿→黄→红 颜色梯度）
- 实时注视点指示器
- 热图显示/隐藏切换
- 热图数据重置
- 面部检测状态提示

## 系统要求

- iOS 18.4+
- iPhone X 及更新机型（需要 TrueDepth 摄像头）
- Xcode 16.3+

## 构建

```bash
# 模拟器构建
xcodebuild -project spotlight.xcodeproj -target spotlight -sdk iphonesimulator build

# 测试
xcodebuild -project spotlight.xcodeproj -target spotlightTests -sdk iphonesimulator test
```

> 面部追踪功能需要在真机上测试，模拟器不支持 `ARFaceTrackingConfiguration`。

## 项目结构

```
spotlight/
├── AR/
│   ├── ARTrackingManager.swift       # AR 会话管理与面部追踪（@Observable, 30fps）
│   └── GazePointConverter.swift      # 3D 视线 → 2D 屏幕坐标投影
├── Heatmap/
│   ├── HeatmapManager.swift          # 网格热图数据管理与 CIImage 渲染（10fps）
│   └── HeatmapOverlayView.swift      # 热图覆盖层视图
├── UI/
│   └── ARViewContainer.swift         # RealityKit ARView 的 UIViewRepresentable 包装
├── ContentView.swift                 # 主视图，集成所有模块
└── spotlightApp.swift                # App 入口
```

## 技术方案

**视线投影**：从 `ARFaceAnchor` 提取双眼位置和 `lookAtPoint`，计算注视射线与摄像头前方虚拟平面的交点，再通过 `ARCamera.projectPoint` 投影到屏幕坐标。虚拟平面距离根据人脸到摄像头的实际距离动态调整。

**热图生成**：二维网格（10pt 精度）累积注视权重，以高斯分布在注视点周围叠加。通过 Core Image 高斯模糊滤镜生成平滑热图，放大至屏幕尺寸显示。

**技术栈**：Swift 5.9+ / SwiftUI / RealityKit / ARKit / Observation 框架 / Core Image

## 许可证

MIT
