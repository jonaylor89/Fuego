import SwiftUI

/// Design comparison view to showcase minimal vs current styling
struct DesignComparisonView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var selectedDesign = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Design", selection: $selectedDesign) {
                Text("Current").tag(0)
                Text("Minimal").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                VStack {
                    Text("Current Design")
                        .font(.headline)
                        .padding(.bottom, 10)
                    
                    SimpleDashboardView()
                        .environmentObject(core)
                        .scaleEffect(0.8)
                }
                
                VStack {
                    Text("Minimal Design")
                        .font(.headline)
                        .padding(.bottom, 10)
                    
                    MinimalDashboardView()
                        .environmentObject(core)
                        .scaleEffect(0.8)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Minimal Design Principles:")
                    .font(.headline)
                    .padding(.top)
                
                Group {
                    Text("• Monospaced typography for consistency")
                    Text("• Ultra-light font weights for softness")
                    Text("• Lowercase text for calm appearance")
                    Text("• Subtle dividers instead of section boxes")
                    Text("• Single focus point (the timer)")
                    Text("• Minimal color palette (primary/secondary only)")
                    Text("• Generous whitespace")
                    Text("• Essential controls only")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 800, height: 600)
    }
}

#Preview {
    DesignComparisonView()
        .environmentObject(FuegoCore())
}
