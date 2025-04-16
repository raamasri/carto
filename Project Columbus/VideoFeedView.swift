//
//  VideoFeedView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI
import AVKit

struct VideoFeedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Placeholder items; replace with real video players later
                    ForEach(0..<5) { idx in
                        ZStack {
                            Color.black
                            Text("Video \(idx + 1)")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .ignoresSafeArea()
            .overlay(
                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .padding()
                        .foregroundColor(.white)
                },
                alignment: .topTrailing
            )
        }
    }
}

struct VideoFeedView_Previews: PreviewProvider {
    static var previews: some View {
        VideoFeedView()
    }
}
