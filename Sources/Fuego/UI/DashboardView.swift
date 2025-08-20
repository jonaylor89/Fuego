import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var core: FuegoCore
    
    var body: some View {
        SimpleDashboardView()
            .environmentObject(core)
    }
}