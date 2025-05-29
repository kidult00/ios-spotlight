# 开发日志 - 用户注视热区检测 App

## 2023-12-14: 项目启动与初步实现

### 1. 项目目标

根据 <mcfile name="requirement.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/requirement.md"></mcfile>，本项目的目标是开发一个 iOS 应用，通过 TrueDepth 摄像头和 ARKit 检测用户视线，在屏幕上实时映射并显示用户注视的热区。颜色越深表示注视概率越高。

### 2. 初期规划与文件结构

参考 <mcfile name="plan.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/plan.md"></mcfile>，我们设定了以下项目结构和核心开发步骤：

*   **项目结构**:
    *   `spotlight/AR/`: 存放 ARKit 相关逻辑。
        *   `ARTrackingManager.swift`: 管理 ARSession、面部追踪、眼部数据提取。
        *   `GazePointConverter.swift`: 3D 注视点到 2D 屏幕坐标转换逻辑。
    *   `spotlight/Heatmap/`: (待创建) 热图相关逻辑。
        *   `HeatmapManager.swift`: (待创建) 管理热图数据。
        *   `HeatmapOverlayView.swift`: (待创建) SwiftUI 视图，渲染热图。
    *   `spotlight/UI/`: 其他 UI 辅助组件。
        *   `ARViewContainer.swift`: 将 ARSCNView 嵌入 SwiftUI。
    *   `spotlight/ContentView.swift`: 主视图，集成 AR 视图和热图。
    *   `Info.plist`: (待修改) 添加摄像头权限描述。

### 3. 已完成工作

#### a. ARKit 面部追踪 (`ARTrackingManager.swift`)
*   创建了 <mcsymbol name="ARTrackingManager" filename="ARTrackingManager.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/ARTrackingManager.swift" startline="6" type="class"></mcsymbol> 类，负责初始化 `ARSession` 并配置 `ARFaceTrackingConfiguration`。
*   实现了 `ARSessionDelegate` 的 `session(_:didUpdate:)` 和 `session(_:didUpdate:)` 方法，用于获取 `ARFaceAnchor` 和 `ARFrame`。
*   通过 `@Published` 属性 (`currentFaceAnchor`, `currentFrame`, `gazeScreenPoint`) 将 AR 数据暴露给 SwiftUI 视图。
*   实现了 `startSession()` 和 `pauseSession()` 方法来控制 AR 会话的生命周期。
*   在 `updateGazePoint()` 方法中，当获取到 `ARFaceAnchor` 和 `ARFrame.camera` 后，调用 <mcsymbol name="GazePointConverter" filename="GazePointConverter.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/GazePointConverter.swift" startline="4" type="class"></mcsymbol> 进行注视点计算。

#### b. 注视点坐标转换 (`GazePointConverter.swift`)
*   创建了 <mcsymbol name="GazePointConverter" filename="GazePointConverter.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/GazePointConverter.swift" startline="4" type="class"></mcsymbol> 类。
*   实现了 <mcsymbol name="projectGaze" filename="GazePointConverter.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/GazePointConverter.swift" startline="49" type="function"></mcsymbol> 方法：
    *   获取头部变换矩阵 (`headTransform`)。
    *   获取左右眼相对于头部的变换矩阵 (`leftEyeTransform`, `rightEyeTransform`)。
    *   计算双眼中心点在头部坐标系中的位置，并转换到世界坐标系 (`eyesMidPointInWorldSpace`)。
    *   获取 `ARFaceAnchor` 的 `lookAtPoint` (面部坐标系中的注视点)，并将其转换为世界坐标系下的注视方向向量 (`gazeVectorInWorld`)。
    *   在摄像头前方定义一个虚拟平面 (距离 `virtualPlaneDistance`)。
    *   计算注视射线与虚拟平面的交点 (`intersectionPointInWorld`)。
    *   使用 `ARCamera.projectPoint(_:orientation:viewportSize:)` 方法将世界坐标系下的交点投影到 2D 屏幕坐标。
*   添加了 `simd_float4x4` 和 `simd_float4` 的扩展，方便提取 `xyz` 坐标。

#### c. AR 视图集成 (`ARViewContainer.swift` 和 `ContentView.swift`)
*   创建了 <mcsymbol name="ARViewContainer" filename="ARViewContainer.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/UI/ARViewContainer.swift" startline="3" type="class"></mcsymbol>，它是一个 `UIViewRepresentable`，用于将 `ARSCNView` 包装起来以便在 SwiftUI 中使用。它持有一个 <mcsymbol name="ARTrackingManager" filename="ARTrackingManager.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/ARTrackingManager.swift" startline="6" type="class"></mcsymbol> 实例，并将其 `session` 赋给 `ARSCNView`。
*   在 <mcsymbol name="ContentView" filename="ContentView.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/ContentView.swift" startline="5" type="class"></mcsymbol> 中：
    *   实例化了 `@StateObject` 类型的 <mcsymbol name="arTrackingManager" filename="ContentView.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/ContentView.swift" startline="6" type="variable"></mcsymbol>。
    *   使用 `ZStack` 将 <mcsymbol name="ARViewContainer" filename="ARViewContainer.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/UI/ARViewContainer.swift" startline="3" type="class"></mcsymbol> 作为背景。
    *   如果 <mcsymbol name="arTrackingManager.gazeScreenPoint" filename="ARTrackingManager.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/ARTrackingManager.swift" startline="12" type="variable"></mcsymbol> 有值，则在对应位置绘制一个红色圆圈作为注视点指示。
    *   在 `.onAppear` 中调用 `arTrackingManager.startSession()`，在 `.onDisappear` 中调用 `arTrackingManager.pauseSession()`。

### 4. 当前状态
*   应用能够启动 ARSession，显示摄像头预览。
*   能够追踪面部，并在 `ARTrackingManager` 中更新 `currentFaceAnchor` 和 `currentFrame`。
*   `GazePointConverter` 能够根据面部和摄像头数据计算出一个屏幕坐标点。
*   `ContentView` 能够在屏幕上显示一个代表注视点的红色圆圈。
*   **注意**: 当前的注视点计算精度可能不高，需要进一步调试和校准。`virtualPlaneDistance` 在 <mcsymbol name="GazePointConverter.projectGaze" filename="GazePointConverter.swift" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/spotlight/AR/GazePointConverter.swift" startline="49" type="function"></mcsymbol> 中被设置为 `0.02` (2cm)，这可能需要根据实际效果调整。

---

## 接下来的计划 (基于 requirement.md)

### 1. 热图统计与可视化 (核心功能)

*   **创建 `HeatmapManager.swift`** (<mcfile name="plan.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/plan.md"></mcfile> 步骤 4):
    *   设计数据结构 (如二维数组或字典) 存储屏幕各区域的注视点频率/时长。
    *   提供方法接收新的注视点屏幕坐标 (`CGPoint`)，并更新热图数据。
    *   实现热点数据平滑/衰减逻辑（可选，用于更动态的热图）。
*   **创建 `HeatmapOverlayView.swift`** (<mcfile name="plan.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/plan.md"></mcfile> 步骤 6):
    *   创建一个 SwiftUI 视图作为覆盖层。
    *   从 `HeatmapManager` 获取处理后的热图数据。
    *   使用 `Canvas` (SwiftUI) 或 Core Graphics (通过 `UIViewRepresentable` 包装的自定义 `UIView`) 渲染热图。
    *   根据 <mcfile name="requirement.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/requirement.md"></mcfile> 建议，可以考虑使用 `CIImage` 结合高斯模糊滤镜生成热图图像，然后显示。颜色深浅根据概率值调整透明度或颜色。
*   **整合到 `ContentView.swift`**:
    *   实例化 `HeatmapManager`。
    *   将 `ARTrackingManager` 计算出的 `gazeScreenPoint` 传递给 `HeatmapManager`。
    *   将 `HeatmapOverlayView` 添加到 `ZStack` 中，位于 AR 视图之上，注视点指示器之下或替换之。

### 2. 关键挑战与解决方案 (来自 <mcfile name="requirement.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/requirement.md"></mcfile>)

*   **视线精度问题**:
    *   **调试与优化 `GazePointConverter.swift`**: 仔细检查坐标系转换、向量计算和投影逻辑。打印中间值进行验证。
    *   **校准机制**: 设计并引导用户完成校准流程（例如，注视屏幕特定点），动态调整映射参数。这可能需要在 `GazePointConverter` 或 `ARTrackingManager` 中增加校准数据和逻辑。
    *   **环境光影响**: 确保 `ARFaceTrackingConfiguration` 的 `isLightEstimationEnabled = true` (已在 <mcfile name="requirement.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/requirement.md"></mcfile> 中提及，检查是否已在 `ARTrackingManager` 中正确配置)。
*   **实时性要求**:
    *   **异步处理**: 将视线计算和热图渲染（特别是复杂的热图生成）放到后台线程处理，避免阻塞主线程。可以使用 `DispatchQueue` 或 `Combine` 的 `subscribe(on:)` 和 `receive(on:)`。
    *   **简化计算**: 评估当前计算的复杂度，寻找优化点。
    *   **Metal 加速**: (高级优化) 如果 Core Graphics/CIImage 性能不足，考虑使用 Metal Performance Shaders (MPS) 进行高效的图像处理和热图生成。

### 3. 隐私与权限

*   **修改 `Info.plist`**: 添加 `NSCameraUsageDescription` (Privacy - Camera Usage Description) 键，并提供清晰的描述，告知用户为何需要摄像头权限。例如："此应用需要访问您的摄像头以进行实时视线追踪和生成屏幕注视热区图。" (来自 <mcfile name="plan.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/plan.md"></mcfile>)

### 4. 代码完善与测试

*   **错误处理**: 在 `ARTrackingManager` 和其他关键部分增加更完善的错误处理和状态反馈。
*   **单元测试/UI测试**: (可选，但推荐) 为关键逻辑（如坐标转换、热图数据管理）编写单元测试。
*   **设备测试**: 在不同兼容设备上进行测试，确保稳定性和性能。

### 5. 扩展功能 (稍后考虑，来自 <mcfile name="requirement.md" path="/Users/bytedance/W/project/mobile_hotspot/spotlight/requirement.md"></mcfile>)

*   多模态交互 (点头、摇头)。
*   数据分析与报告生成。
*   云服务集成。

### 优先级

1.  **核心热图功能**: `HeatmapManager` 和 `HeatmapOverlayView` 的实现。
2.  **视线精度提升**: 调试 `GazePointConverter`，实现初步的校准机制。
3.  **Info.plist 权限**: 添加摄像头使用描述。
4.  **性能优化**: 异步处理。
5.  **进一步的精度优化和用户体验提升**。