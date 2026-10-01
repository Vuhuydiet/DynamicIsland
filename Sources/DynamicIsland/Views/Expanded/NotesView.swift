import SwiftUI

public struct NotesView: View {
    @ObservedObject var notes = NotesManager.shared
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(.yellow)
                        .font(IslandFont.iconRegular)
                    Text("Quick Scratchpad")
                        .font(IslandFont.title)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: {
                        notes.copyAll()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(IslandFont.iconMicro)
                            Text("Copy")
                        }
                        .font(IslandFont.caption)
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                    
                    Button(action: {
                        withAnimation(IslandSpring.bouncy) {
                            notes.clear()
                        }
                    }) {
                        Text("Clear")
                            .font(IslandFont.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.90))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            // Text Editor
            TextEditor(text: $notes.noteText)
                .font(IslandFont.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(height: 84)
                .padding(.horizontal, 14)
        }
        .padding(.bottom, 6)
    }
}
