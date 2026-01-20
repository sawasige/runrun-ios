import Foundation

/// NavigationStackで使用する画面遷移先の型
enum ScreenType: Hashable {
    case profile(UserProfile)
    case yearDetail(user: UserProfile, initialYear: Int?)
    case monthDetail(user: UserProfile, year: Int, month: Int)
    case runDetail(record: RunningRecord, user: UserProfile)
    case weeklyStats(user: UserProfile)
    case licenses
}
