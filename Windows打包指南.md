# 乘风计划 iOS App - Windows 打包完整指南

## 你的情况
- 电脑：Windows 10
- 网络：国内（无翻墙）
- 需求：打包 IPA，不上架，侧载安装
- 要求：简单、不包月、免费

---

## 核心事实

**iOS 原生 Swift 项目必须用 Xcode 编译，Windows 无法直接编译。**

所有方案的本质都是：**把代码传到云端 macOS 机器上编译，然后下载 IPA。**

---

## 推荐方案：GitHub Actions（0 元）

### 为什么推荐
- 完全免费（公开仓库无限免费）
- 不包月、按量使用
- 自动化，一键触发

### 国内网络问题解决

GitHub 在国内访问慢，但**不影响使用**，只需一次性配置加速：

**方法一：修改 hosts（免费）**
1. 访问 https://github.com/521xueweihan/GitHub520
2. 下载 `hosts` 文件内容
3. 追加到 Windows hosts 文件：`C:\Windows\System32\drivers\etc\hosts`
4. 刷新 DNS：打开 CMD 执行 `ipconfig /flushdns`

**方法二：使用 Ghips 工具（更简单）**
1. 搜索下载 Ghips 工具
2. 一键自动获取 GitHub 最快 IP 并修改 hosts

**方法三：使用镜像加速**
- 代码推送使用 Gitee 镜像仓库
- 或使用 ghproxy.com 代理

---

## 操作步骤

### 第一步：注册 GitHub 账号
1. 打开 https://github.com
2. 注册免费账号（如果已有则跳过）

### 第二步：创建仓库并上传代码
1. 在 GitHub 上新建仓库（Public 公开，免费构建）
2. 在项目根目录打开 PowerShell：

```powershell
cd "D:\开发工具\iPhone 乘风计划\ChengFengPlan_v2"

# 初始化 Git
git init
git add .
git commit -m "乘风计划 iOS 项目初始版本"

# 关联远程仓库（替换为你的用户名）
git remote add origin https://github.com/你的用户名/ChengFengPlan.git
git branch -M main
git push -u origin main
```

### 第三步：触发构建
1. 打开你的 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 左侧选择 **iOS Build**
4. 点击 **Run workflow** → **Run workflow**
5. 等待 5-10 分钟

### 第四步：下载 IPA
1. 构建完成后，点击构建记录
2. 滚动到底部 **Artifacts** 区域
3. 下载 **ChengFengPlan-IPA.zip**
4. 解压得到 `ChengFengPlan_unsigned.ipa`

### 第五步：侧载安装到 iPhone
1. 下载 [爱思助手](https://www.i4.cn)（Windows 版）
2. 用数据线连接 iPhone
3. 工具箱 → IPA 签名 → 选择下载的 IPA
4. 登录你的普通 Apple ID（免费）
5. 签名完成后安装到设备
6. iPhone 设置 → 通用 → VPN 与设备管理 → 信任证书

> 有效期 7 天，到期重新签名即可。

---

## 备选方案对比

| 方案 | 费用 | 国内访问 | 操作难度 |
|------|------|---------|---------|
| **GitHub Actions** | 0元 | 需加速(一次性配置) | 中等 |
| **Codemagic** | 0元(500分钟/月) | 需加速 | 简单 |
| **Gitee Go** | 有限免费 | 国内直连 | 需自配macOS |
| **Appuploader** | 0元 | 国内直连 | 仅上传,不编译 |

---

## 费用总结

| 项目 | 费用 |
|------|------|
| GitHub Actions 构建 | **0 元** |
| Apple ID 签名 | **0 元**（普通账号） |
| 爱思助手 | **0 元** |
| **总计** | **0 元** |

---

## 注意事项

1. **iOS 16+** 需在 iPhone 上开启「开发者模式」（设置 > 隐私与安全）
2. **免费 Apple ID** 签名有效期 7 天，到期需重新签名
3. **GitHub 公开仓库**构建完全免费，私有仓库每月 2000 分钟免费
4. 如需**自动续签**，可使用 AltStore（需电脑保持运行）
