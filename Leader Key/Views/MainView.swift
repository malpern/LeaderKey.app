//
//  MainView.swift
//  Leader Key
//
//  Created by Mikkel Malmberg on 19/04/2024.
//

import SwiftUI
import AppKit

let MAIN_VIEW_SIZE: CGFloat = 200

struct BouncingDot: View {
    @State private var yOffset: CGFloat = 0
    @State private var bounceCount = 0
    let onComplete: () -> Void
    
    var body: some View {
        Text("●")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .offset(y: yOffset)
            .onAppear {
                startBounceAnimation()
            }
    }
    
    private func startBounceAnimation() {
        let duration = 0.3
        let springResponse = 0.4
        let springDamping = 0.5
        let bounceHeight: CGFloat = 25
        
        // Initial bounce up
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            yOffset = -bounceHeight
        }
        
        // Bounce down below center
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                yOffset = bounceHeight * 0.7
            }
            
            // Bounce back up, but not as high
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                    yOffset = -bounceHeight * 0.4
                }
                
                // Final small bounce down
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                        yOffset = bounceHeight * 0.2
                    }
                    
                    // Come to rest at center
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                            yOffset = 0
                        }
                        
                        // Wait for the final animation to complete before calling onComplete
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.8) {
                            onComplete()
                        }
                    }
                }
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var userState: UserState
    @State private var isReloading = false
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .frame(width: MAIN_VIEW_SIZE, height: MAIN_VIEW_SIZE)
            
            if isReloading {
                BouncingDot(onComplete: {
                    isReloading = false
                    userState.display = nil
                })
            } else {
                Text(userState.currentGroup?.key ?? userState.display ?? "●")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
            }
        }
        .frame(width: MAIN_VIEW_SIZE, height: MAIN_VIEW_SIZE)
        .clipShape(RoundedRectangle(cornerRadius: 25.0, style: .continuous))
        .onChange(of: userState.display) { newValue in
            if newValue == "🔃" {
                isReloading = true
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(UserState(userConfig: UserConfig()))
    }
}
