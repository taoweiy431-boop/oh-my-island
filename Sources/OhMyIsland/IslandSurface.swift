/// 面板当前展示的 "面"——同一时刻只能有一个
enum IslandSurface: Equatable {
    /// 收起状态，只显示 compact bar
    case collapsed
    /// 用户主动展开，显示 session 列表
    case sessionList
    /// 显示权限审批卡片
    case approvalCard(sessionId: String)
    /// 显示问答卡片
    case questionCard(sessionId: String)
    /// 自动展开显示完成通知
    case completionCard(sessionId: String)
    /// 聊天视图
    case chat(sessionId: String)
    /// Buddy 卡片
    case buddyCard
    /// 用量监控面板
    case usagePanel
    /// 设置面板（嵌入灵动岛内）
    case settingsPanel
    /// 环境安全检测面板
    case environmentCheck
    /// 会员等级卡片
    case membershipCard

    var isExpanded: Bool { self != .collapsed }

    /// 当前 surface 关联的 session ID（如有）
    var sessionId: String? {
        switch self {
        case .collapsed, .sessionList, .buddyCard, .usagePanel, .settingsPanel, .environmentCheck, .membershipCard: return nil
        case .approvalCard(let id), .questionCard(let id), .completionCard(let id), .chat(let id): return id
        }
    }
}
