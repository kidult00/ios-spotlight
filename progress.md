# Spotlight 开发进展

## 2026-03-26: 注视投影算法重构 + 热图扩散优化 + ARFrame 内存修复

### 问题
1. **注视红点不跟随视线**：红点始终在鼻子位置，几乎不随视线移动
2. **热图热区过小**：热区聚焦为一个很小的点，不像专业眼动追踪热图
3. **ARFrame 滞留**：ARKit 报告 "retaining 11 ARFrames"，可能导致摄像头停止投递帧

### 根因分析

#### 投影算法缺陷（核心问题）
旧算法使用射线-虚拟平面交点 + `projectPoint` 投影。虚拟平面位于 `cameraPosition + cameraForward * faceToCamera * 0.9`，距用户脸部仅约 3cm。注视射线在 3cm 内几乎无横向偏移，`projectPoint` 将交点投影到鼻子附近，灵敏度仅为屏幕宽度的 2-3%。

#### 热图参数
高斯核 radius=3（30pt）、sigma=2.0（20pt）、CIGaussianBlur sigma=2.0 过小，单个注视点可见热区仅 ~60pt 直径。

#### ARFrame 内存
`DispatchQueue.main.async` 闭包隐式捕获 `faceAnchor`（持有 ARFrame 强引用），主线程繁忙时闭包排队导致帧积压。

### 修改

#### GazePointConverter.swift — 重写投影算法
- **新方法**：基于注视角度的直接投影
  1. 将注视方向转换到摄像头坐标系
  2. 计算角度偏移 (tanX, tanY)
  3. 在摄像头前方 1m 处构造合成 3D 点
  4. 用 `projectPoint` 投影到屏幕
- 灵敏度由注视角度直接决定，与面部距离无关
- 移除了虚拟平面和射线交点计算

#### HeatmapManager.swift — 热图优化
- `radius`: 3 → 8（核覆盖 160pt 方形）
- `sigma`: 2.0 → 4.0（屏幕空间扩散 40pt）
- CIGaussianBlur: 2.0 → 5.0（~50pt 模糊羽化）
- `alpha` 乘数: 0.8 → 1.5（周边热区可见）
- 强度阈值: 0.01 → 0.005（平滑边缘）
- 热图图像生成移至后台线程，避免阻塞主线程

#### ARTrackingManager.swift — 内存修复
- 用 `autoreleasepool` 包裹帧数据处理
- 闭包不再捕获 `faceAnchor`，改为提前提取 Bool 值

### 状态
- 已构建通过（iphoneos）
- 待真机验证：注视红点跟随、热图扩散效果、ARFrame 警告消除
- 可能需要微调：X 轴镜像方向、灵敏度乘数
