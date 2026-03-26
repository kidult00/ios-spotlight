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

---

## 2026-03-26: 灵敏度放大 + 眨眼检测 + 校准系统 + 单元测试

### 问题
1. **注视红点范围仍然受限**：虽然投影算法已改为角度法，但原始 tanX/tanY 范围（±0.17~0.27）远小于摄像头 FOV 要求（tan(30°)≈0.577），红点无法到达屏幕边缘
2. **眨眼时红点跳动**：眨眼瞬间 ARKit 眼部数据不稳定，导致注视点突变
3. **个体差异无法适配**：不同用户眼球旋转范围不同，固定参数无法满足所有人

### 修改

#### GazePointConverter.swift — 灵敏度放大
- 添加 `sensitivityX: Float = 2.5` 和 `sensitivityY: Float = 3.0`
- tanX/tanY 经放大后再构造合成点：`amplifiedTanX = tanX * sensitivityX`
- 重构 `extractRawGazeAngles()` 提取原始角度值，供校准和投影复用
- 新增 `projectGazeWithCalibration()` 方法：使用仿射变换直接映射到屏幕坐标

#### ARTrackingManager.swift — 眨眼检测 + EMA 平滑
- 眨眼检测：读取 `blendShapes[.eyeBlinkLeft/.eyeBlinkRight]`，超 0.5 阈值时冻结注视点
- EMA 平滑：`smoothingFactor=0.25`（新值权重 0.75），30fps 下约 2 帧延迟
- 校准集成：校准模式下将原始 tanX/tanY 发送给 CalibrationManager

#### 校准系统（新增 3 个文件）
- `CalibrationData.swift` — 仿射变换参数 + 最小二乘拟合 + UserDefaults 持久化
- `CalibrationManager.swift` — 9 点校准流程状态机，每点采集 1.5s，去头尾 20% 取均值
- `CalibrationView.swift` — 校准 UI：黑色背景 + 脉动白色圆点 + 进度环 + 完成/失败状态

#### ContentView.swift — 校准集成
- 新增校准按钮（scope 图标），已校准时显示绿色边框
- 覆盖层显示校准视图
- 启动时加载持久化的校准数据

#### 单元测试（4 个新测试文件，14 个测试用例）
- `GazeConverterTests` — 灵敏度乘数范围覆盖、自定义值
- `BlinkDetectionTests` — 阈值边界、单眼/双眼
- `CalibrationTests` — 最小二乘拟合、最小样本数、持久化
- `SmoothingTests` — EMA 收敛、尖峰抑制、极端参数

### 状态
- iphoneos 构建通过
- 14 个单元测试全部通过

---

## 2026-03-26: 校准仿射修复 + 红点平滑增强 + 热图时间衰减

### 问题
1. **校准后纵向无移动**：独立 X/Y 回归丢失交叉轴信息，portrait 模式下摄像头坐标轴与屏幕坐标轴有 90° 旋转
2. **红点跳动频繁**：`smoothingFactor=0.25`（新值权重 75%）平滑不足
3. **热图变化极慢**：只累积不衰减，旧数据永不消失，无法反映当前注意力

### 修改

#### CalibrationData.swift — 完整 2D 仿射变换
- 从 4 参数（scaleX/Y, offsetX/Y）改为 6 参数完整仿射：`screenX = ax*tanX + bx*tanY + cx`
- 多元线性回归（正规方程 + Cramer 法则）替代独立回归
- 最小样本数从 2 提升到 3（3 个未知数需至少 3 个方程）
- 新增 `mapToScreen()` 方法封装变换+钳位逻辑
- 持久化 key 升级到 v2，自动清理旧版本

#### ARTrackingManager.swift — 平滑增强
- `smoothingFactor`: 0.25 → 0.55（新值权重从 75% 降到 45%，约 4 帧延迟）

#### HeatmapManager.swift — 时间衰减
- 每帧对全网格乘以 `decayFactor=0.97`：1 秒后旧值衰减到 40%，2 秒后 16%
- 衰减过程中同步重算 maxValue，保持归一化准确

### 状态
- iphoneos 构建通过，19 个单元测试全部通过
- 已更新 docs/原理.md 反映完整当前架构
- 待真机验证：红点平滑度、热图实时性、校准纵向移动
