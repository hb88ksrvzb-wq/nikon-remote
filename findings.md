# 发现与决策

## 需求
- iOS 测试软件，直连尼康相机（Z6/Z7/Z8/Z9 等 Z 系列）
- 远程拍摄（完整参数控制：光圈/快门/ISO 等）
- 照片/视频自动上传到手机相册，无损格式（NEF/RAW）
- 开发环境：只有 Windows，无 Mac → 只能写源码 + 构建文档

## 研究发现
参考实现：gphoto2 libgphoto2 camlibs/ptp2（对 Nikon Z6 已有专门适配注释，证明尼康 Z 系列走 PTP/IP）

### PTP/IP 线协议（已从 ptpip.c / ptpip.h / PTPIP.TXT 确认）
- TCP 端口：命令/数据 15740，事件 15741
- 包结构：`len(4 LE) + type(4 LE) + data`，无序号无参数计数（紧凑格式，gphoto2 实测可连 Nikon）
- 包类型：1=InitCmdReq 2=InitCmdAck 3=InitEventReq 4=InitEventAck 5=InitFail 6=CmdReq 7=CmdResp 8=Event 9=StartData 0xA=Data 0xB=Cancel 0xC=EndData 0xD=Ping 0xE=Pong
- 握手（gphoto2 流程，无需 1280 字节初始化包）：
  1. 连 15740，发 InitCmdRequest：`[len][type=1][16B GUID][UTF16LE主机名+'\0'][verMinor][verMajor]`
  2. 收 InitCmdAck：`[len][type=2][4B sessionID][16B GUID][UTF16LE相机名]`
  3. 连 15741，发 InitEventRequest：`[len=12][type=3][4B sessionID]`
  4. 收 InitEventAck：`[len=8][type=4]`
  5. 命令通道发 PTP OpenSession(0x1002, param=sessionID)
- CmdReq 布局：`len(4) type(6) dataphase(4: 2=发数据/1=收数据或无) code(2) transid(4) params(n*4)`，len=18+4n
- CmdResp 布局：`code(2) transid(4) params`（参数数由长度推算）
- Event 布局：`code(2) transid(4) params`
- StartData：`transid(4) totalLen(4) unknown(4)`；Data/EndData：`transid(4) data`
- 收数据顺序：Start(9) → Data(0xA)/End(0xC) → Resp(7)；发数据顺序：Req(6,phase=2) → Start(9) → Data(0xA)…End(0xC) → Resp(7)

### 关键 PTP 操作码
0x1001 GetDeviceInfo / 0x1002 OpenSession / 0x1003 CloseSession / 0x1004 GetStorageIDs / 0x1007 GetObjectHandles / 0x1008 GetObjectInfo / 0x1009 GetObject / 0x100E InitiateCapture(0xFFFFFFFF, 0) / 0x1014 GetDevicePropDesc / 0x1015 GetDevicePropValue / 0x1016 SetDevicePropValue / 尼康拍视频 0x920A StartMovieRec / 0x920B EndMovieRec

### 响应码
0x2001 OK / 0x2002 GeneralError / 0x2003 SessionNotOpen / 0x200A DevicePropNotSupported / 0x200F AccessDenied / 0x2019 DeviceBusy / 0x201C InvalidDevicePropValue / 0x201D InvalidParameter

### 事件码
0x4002 ObjectAdded / 0x400D CaptureComplete / 尼康 0xC101 ObjectAddedInSDRAM / 0xC102 CaptureCompleteRecInSdram / 0xC108 MovieRecordComplete / 0xC10A MovieRecordStarted

### 设备属性（标准）
0x5007 FNumber(光圈) / 0x500D ExposureTime(快门) / 0x500F ExposureIndex(ISO) / 0x5005 WhiteBalance / 0x500E ExposureProgramMode / 0x5010 ExposureBiasCompensation
### 设备属性（尼康扩展，Z 系列用 32 位属性码！）
0xD030 ShootingMode / 0xD035 RemoteMode / 0xD036 VideoMode / 0xD0B5 ISOControlSensitivity / 0xD100 ExposureTime(快门) / 0xF002 ISO / 0xF003 FNumber / 0xF004 ShutterSpeed
- 注意：gphoto2 注释明确「尼康属性码用 32 位」（如 0x1D012），解析 GetDevicePropDesc 时按 4 字节读属性码

### 数据类型码
1=INT8 2=UINT8 3=INT16 4=UINT16 5=INT32 6=UINT32 7=INT64 8=UINT64 9/0xA=128bit 0x4000|type=数组 0xFFFF=STRING；A6080 类型其实是 UINT32，值 = f值*2^16

### DevicePropDesc 数据集顺序
propcode(尼康4字节) + datatype(2) + getset(1) + 默认值 + 当前值 + formflag(1) + [range(min/max/step) 或 enum(count + 值)]

### ObjectInfo 数据集顺序
storageID(4) format(2) protection(2) size(4) thumbFmt(2) thumbSize(4) thumbW/H(4,4) imageW/H(4,4) bitDepth(4) parent(4) assocType(2) assocDesc(4) seqNo(4) filename(str) captureDate(str) modDate(str) keywords(str)

### DeviceInfo 数据集顺序
version(2) vendorID(4) vendorVer(2) vendorDesc(str) funcMode(2) ops(uint16[]) events(uint16[]) props(uint16[]) captureFmts(uint16[]) imageFmts(uint16[]) mfr(str) model(str) deviceVer(str) serial(str)

## 技术决策
| 决策 | 理由 |
|------|------|
| 原生 BSD socket + Swift 实现 PTP/IP | 无第三方依赖，可在 Windows 上编写，Mac 上直接编译 |
| 采用 gphoto2 紧凑线格式（无 seqno/paramCount） | 开源参考实现实测可连 Nikon WU-1a/D90/Z 系列 |
| 握手不发送 1280 字节初始化包 | gphoto2 无此包即能连 Nikon；加常量开关作兜底 |
| 用 GetDevicePropDesc 枚举参数有效值 | 兼容 Z6/Z7/Z8/Z9 不同属性码（0x5007/0xF003 等） |
| 文件名扩展名判断照片/视频 | 不依赖 format code 映射，可靠 |
| PHAssetCreationRequest.addResource 存 NEF | 原样导入 RAW 无损，Photos 保留 NEF |
| 前台事件驱动 + 轮询兜底实现自动上传 | iOS 后台 socket 受限，前台自动是现实方案 |
| XcodeGen 生成工程 | 无法在 Windows 生成 .xcodeproj |

## 遇到的问题
| 问题 | 解决方案 |
|------|---------|
|      |         |

## 资源
- https://github.com/gphoto/libgphoto2 （开源 PTP/PTP-IP 参考实现）
- https://github.com/cj123/ (Cascable/iPhone 远程控制)
- PTP-IP 规范基于 PIMA 15740

## 视觉/浏览器发现
-（待补充）

---
*每执行2次查看/浏览器/搜索操作后更新此文件*
*防止视觉信息丢失*
