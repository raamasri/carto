// created by raama srivatsan on 4/16/25
import SwiftUI
import AVKit

struct VideoFeedView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Temporary local demo files included in the asset catalog (add sample1.mp4, sample2.mp4 to the project).
    private let videoNames = ["sample1", "sample2"]
    
    var body: some View {
        TabView {
            ForEach(videoNames, id: \.self) { name in
                ZStack {
                    // Full‑screen looping video
                    LoopingPlayerView(videoName: name)
                        .ignoresSafeArea()
                    
                    // Overlay: close button (top‑right)
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                                    .padding(.trailing, 12)
                            }
                        }
                        Spacer()
                    }
                    
                    // Overlay: social actions + caption (bottom area)
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            // Caption area
                            VStack(alignment: .leading, spacing: 6) {
                                Text("@username")
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Text("Sample caption here #hashtag")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            // Action buttons
                            VStack(spacing: 22) {
                                Button { /* like action */ } label: {
                                    Image(systemName: "heart")
                                        .font(.title2)
                                }
                                Button { /* comment action */ } label: {
                                    Image(systemName: "bubble.right")
                                        .font(.title2)
                                }
                                Button { /* share action */ } label: {
                                    Image(systemName: "arrowshape.turn.up.right")
                                        .font(.title2)
                                }
                            }
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // vertical swipe
    }
}

/// A UIViewRepresentable wrapper that loops a local MP4 forever and fills its bounds.
struct LoopingPlayerView: UIViewRepresentable {
    let videoName: String
    
    func makeUIView(context: Context) -> UIView {
        PlayerContainer(name: videoName)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) { }
    
    private class PlayerContainer: UIView {
        private let playerLayer = AVPlayerLayer()
        private var looper: AVPlayerLooper?
        
        init(name: String) {
            super.init(frame: .zero)
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
            
            let asset = AVAsset(url: url)
            let item  = AVPlayerItem(asset: asset)
            let queue = AVQueuePlayer()
            looper = AVPlayerLooper(player: queue, templateItem: item)
            queue.play()
            
            playerLayer.player = queue
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

struct VideoFeedView_Previews: PreviewProvider {
    static var previews: some View {
        VideoFeedView()
            .previewDevice("iPhone 15 Pro")
    }
}
