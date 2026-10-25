import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct BlurStudioView: View {
    @EnvironmentObject var unlock: UnlockStore
    @State private var pick: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var strokes: [[CGPoint]] = []   // normalized 0...1 in image space
    @State private var current: [CGPoint] = []
    @State private var brush: Double = 0.05
    @State private var preview: UIImage?
    @State private var message: String?
    @State private var paywall = false

    var body: some View {
        VStack(spacing: 12) {
            EyebrowTitle(latin: "Soft Focus", title: "写真ぼかし")
            Text("書き終えた婚姻届の写真で、住所や本籍などを指でなぞるとぼかせます。SNSに載せる前にどうぞ。写真は端末の中だけで処理します。")
                .font(.system(size: 13)).foregroundStyle(Palette.mist)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let photo {
                canvas(photo)
                HStack {
                    Text("ぼかしの太さ").font(.system(size: 13)).foregroundStyle(Palette.mist)
                    Slider(value: $brush, in: 0.02...0.12)
                }
                HStack(spacing: 10) {
                    Button("1つ戻す") { if !strokes.isEmpty { strokes.removeLast(); rerender() } }
                        .buttonStyle(PillButtonStyle(filled: false))
                    Button("全部消す") { strokes = []; rerender() }
                        .buttonStyle(PillButtonStyle(filled: false))
                    Spacer()
                    Button("写真に保存") { save() }.buttonStyle(PillButtonStyle())
                }
            } else {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 50, weight: .thin))
                        .foregroundStyle(Palette.champagne)
                    if unlock.unlocked {
                        PhotosPicker(selection: $pick, matching: .images) {
                            Text("写真を選ぶ")
                        }
                        .buttonStyle(PillButtonStyle())
                    } else {
                        Button("全機能（買い切り）で使えます") { paywall = true }
                            .buttonStyle(PillButtonStyle())
                    }
                }
                Spacer()
            }
            if let message {
                Text(message).font(.system(size: 13)).foregroundStyle(Palette.champagne)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .background(Palette.porcelain.ignoresSafeArea())
        .toolbar {
            if photo != nil, unlock.unlocked {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $pick, matching: .images) { Text("別の写真") }
                }
            }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    photo = Self.upright(img)
                    strokes = []
                    preview = photo
                    message = nil
                }
            }
        }
        .sheet(isPresented: $paywall) { PaywallView() }
        .onAppear {
            if LaunchDemo.has("-blurSample"), photo == nil { loadSample() }
        }
    }

    private func canvas(_ base: UIImage) -> some View {
        GeometryReader { geo in
            let fit = Self.fitRect(base.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: preview ?? base).resizable()
                    .frame(width: fit.width, height: fit.height)
                    .offset(x: fit.minX, y: fit.minY)
                Path { path in
                    for pts in [current] where pts.count > 1 {
                        path.addLines(pts.map { CGPoint(x: fit.minX + $0.x * fit.width, y: fit.minY + $0.y * fit.height) })
                    }
                }
                .stroke(Palette.champagne.opacity(0.6),
                        style: StrokeStyle(lineWidth: brush * fit.width, lineCap: .round, lineJoin: .round))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let x = (v.location.x - fit.minX) / fit.width
                let y = (v.location.y - fit.minY) / fit.height
                current.append(CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1)))
            }.onEnded { _ in
                if !current.isEmpty { strokes.append(current) }
                current = []
                rerender()
            })
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func rerender() {
        guard let photo else { return }
        preview = Self.apply(strokes: strokes, brush: brush, to: photo)
    }

    private func save() {
        guard let img = preview ?? photo else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        message = "写真に保存しました。"
    }

    private func loadSample() {
        let size = CGSize(width: 1200, height: 860)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.97, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.6, green: 0.35, blue: 0.3, alpha: 0.8).setStroke()
            let lines: [(String, CGFloat)] = [("婚　姻　届", 70), ("夫になる人　山田 太郎", 200), ("妻になる人　山田 花子", 290),
                                              ("住所　東京都千代田区千代田1丁目2番3号", 420), ("本籍　東京都千代田区千代田一丁目1番地", 520)]
            for (t, y) in lines {
                let f = UIFont(name: Typeface.minchoRegular, size: y < 100 ? 60 : 38) ?? .systemFont(ofSize: 38)
                (t as NSString).draw(at: CGPoint(x: 80, y: y), withAttributes: [.font: f, .foregroundColor: UIColor.black])
                ctx.cgContext.stroke(CGRect(x: 60, y: y - 14, width: 1080, height: 74))
            }
        }
        photo = img
        strokes = [[CGPoint(x: 0.22, y: 0.53), CGPoint(x: 0.9, y: 0.53)], [CGPoint(x: 0.22, y: 0.65), CGPoint(x: 0.9, y: 0.65)]]
        brush = 0.07
        rerender()
    }

    static func fitRect(_ img: CGSize, in box: CGSize) -> CGRect {
        let s = min(box.width / img.width, box.height / img.height)
        let w = img.width * s, h = img.height * s
        return CGRect(x: (box.width - w) / 2, y: (box.height - h) / 2, width: w, height: h)
    }

    static func upright(_ img: UIImage) -> UIImage {
        let maxSide: CGFloat = 2400
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func apply(strokes: [[CGPoint]], brush: Double, to image: UIImage) -> UIImage {
        guard !strokes.isEmpty, let cg = image.cgImage else { return image }
        let size = CGSize(width: cg.width, height: cg.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let maskImage = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let c = ctx.cgContext
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(brush * size.width)
            c.setLineCap(.round); c.setLineJoin(.round)
            for pts in strokes {
                let mapped = pts.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                if mapped.count == 1 {
                    c.addLines(between: [mapped[0], mapped[0]])
                } else {
                    c.addLines(between: mapped)
                }
                c.strokePath()
            }
        }
        guard let maskCG = maskImage.cgImage else { return image }
        let input = CIImage(cgImage: cg)
        let pixel = CIFilter.pixellate()
        pixel.inputImage = input.clampedToExtent()
        pixel.scale = Float(max(size.width, size.height) / 45)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = pixel.outputImage
        blur.radius = Float(max(size.width, size.height) / 70)
        guard let softened = blur.outputImage?.cropped(to: input.extent) else { return image }
        let blend = CIFilter.blendWithMask()
        blend.inputImage = softened
        blend.backgroundImage = input
        blend.maskImage = CIImage(cgImage: maskCG)
        let context = CIContext()
        guard let out = blend.outputImage, let result = context.createCGImage(out, from: input.extent) else { return image }
        return UIImage(cgImage: result)
    }
}
