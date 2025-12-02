# 易飞ERP接口系统软件开发说明书

## 1. 项目概述 (Project Overview)

本项目是基于Delphi开发的易飞ERP（YiFei ERP）接口系统，旨在解决传统ERP系统与现代移动办公平台（企业微信、OA系统）之间的数据孤岛问题。通过本系统，可以实现ERP业务单据（如销售订单、采购请购单）自动同步通知到企业微信，或推送到OA系统发起审批流程。

## 2. 技术架构 (Technical Architecture)

*   **开发语言**: Delphi 7 / Delphi 2007+ (Object Pascal)
*   **数据库连接**: ADO (ActiveX Data Objects)
*   **网络通信**: Indy Components (TIdHTTP)
*   **数据格式**: JSON (使用 SuperObject 库)
*   **安全协议**: OpenSSL (用于企业微信 HTTPS 通信)

## 3. 项目结构 (Project Structure)

```text
Root/
├── bin/                  # 编译输出目录
│   ├── YiFei.exe         # 主程序
│   ├── DBCfg.ini         # 数据库配置文件
│   ├── libeay32.dll      # OpenSSL 库 (必须)
│   └── ssleay32.dll      # OpenSSL 库 (必须)
├── Service/              # 业务逻辑服务层 (DataModules)
│   ├── DbConService.pas  # 数据库连接服务 (易飞ERP连接)
│   ├── WeComService.pas  # 企业微信接口服务
│   ├── OAService.pas     # OA系统接口服务
│   └── InterfaceIntegration.pas # 业务集成逻辑
├── Form/                 # 界面层
├── Unit/                 # 公共单元
└── doc/                  # 文档
```

## 4. 核心模块说明 (Core Modules)

### 4.1 数据库连接服务 (DbConService)
*   **功能**: 负责读取 `DBCfg.ini` 配置文件，建立与易飞ERP数据库（SQL Server）的连接。
*   **关键组件**: `TADOConnection`
*   **配置项**: Host, User, Password, DbName。

### 4.2 企业微信服务 (WeComService)
*   **功能**: 封装企业微信API，处理鉴权和消息推送。
*   **主要特性**:
    *   自动管理 `Access_Token`，包含过期重试机制。
    *   支持 SSL/HTTPS (通过 `TIdSSLIOHandlerSocketOpenSSL`)。
    *   提供 `SendMessage` 方法发送文本卡片消息。
*   **依赖**: 需要 `libeay32.dll` 和 `ssleay32.dll`。

### 4.3 OA集成服务 (OAService)
*   **功能**: 与OA系统对接，自动创建审批流。
*   **方法**: `CreateWorkflow`，接收标题、申请人和表单JSON数据。

### 4.4 业务集成管理器 (InterfaceIntegration)
*   **功能**: 系统的核心调度器，连接数据库与API服务。
*   **实现了两个主要流程**:
    1.  **销售订单同步 (`SyncNewOrdersToWeCom`)**:
        *   监控表 `COPTG` (销售单头)。
        *   逻辑: 查询当天未同步 (`UDF01 IS NULL`) 的订单。
        *   动作: 推送企业微信通知，更新 `UDF01 = 'Y'`。
    2.  **采购请购同步 (`SyncPurchaseRequestsToOA`)**:
        *   监控表 `PURTA` (请购单头)。
        *   逻辑: 查询未审核 (`TA018='N'`) 且未推送 (`UDF02 IS NULL`) 的单据。
        *   动作: 创建OA流程，更新 `UDF02 = 'Sent'`。

## 5. 配置与部署 (Configuration & Deployment)

### 5.1 环境准备
1.  确保运行环境安装了必要的数据库驱动 (SQL Server Native Client)。
2.  将 OpenSSL 动态库 (`libeay32.dll`, `ssleay32.dll`) 放入 `bin/` 目录或系统路径。

### 5.2 配置文件 (DBCfg.ini)
在 `bin/` 目录下创建或修改 `DBCfg.ini`:

```ini
[CONFIG]
HOST=192.168.1.100
USER=sa
PASSWORD=encrypted_password_here
DBNAME=DSCSYS
```
*注意: 密码通常是加密存储的，需使用配置工具生成。*

### 5.3 代码配置
在 `InterfaceIntegration.pas` 中填入实际的 API 凭证：
```pascal
FWeCom := TWeComService.Create(nil, 'YOUR_CORP_ID', 'YOUR_CORP_SECRET');
FOA := TOAService.Create(nil, 'http://oa.yourcompany.com', 'YOUR_API_KEY');
```

## 6. 二次开发指南 (Extension Guide)

### 添加新的同步任务
1.  在 `InterfaceIntegration` 类中添加新的方法，例如 `SyncInventoryAlert`。
2.  编写 SQL 查询易飞数据库（例如查询库存表 `INVMB`）。
3.  调用 `FWeCom.SendMessage` 发送通知。
4.  执行 SQL `UPDATE` 语句标记该记录已处理，防止重复发送。

```pascal
// 示例: 库存预警
procedure TInterfaceManager.SyncInventoryAlert;
begin
  // SELECT ... FROM INVMB WHERE MB064 < MB065 ...
  // SendMessage(...)
end;
```

---
*文档生成日期: 2024*
