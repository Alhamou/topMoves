import SwiftUI
import AppKit
import CryptoKit

@MainActor
final class PosterCache {
    static let shared = PosterCache()
    private let memory = NSCache<NSString, NSImage>()
    private var pending: [String: Task<NSImage?, Never>] = [:]
    private let directory: URL
    private let session: URLSession
    private init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("TopMovies/Posters")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.totalCostLimit = 48 * 1024 * 1024
        let config = URLSessionConfiguration.default; config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files {
                let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                if Date().timeIntervalSince(date ?? .distantPast) > 604800 { try? FileManager.default.removeItem(at: file) }
            }
        }
    }
    func image(path: String, size: String = "w500") async -> NSImage? {
        guard path.hasPrefix("/"), !path.contains(".."), !path.contains("?"), !path.contains("#") else { return nil }
        let cacheKey = "\(size)\(path)" as NSString
        if let image = memory.object(forKey: cacheKey) { return image }
        let keyString = "\(size)\(path)"
        if let task = pending[keyString] { return await task.value }
        let filename = SHA256.hash(data: Data(keyString.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(filename)
        let session = session
        let task = Task<NSImage?, Never> {
            if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               Date().timeIntervalSince(date) < 604800, let image = NSImage(contentsOf: file) { return image }
            guard let url = URL(string: "https://image.tmdb.org/t/p/\(size)\(path)"),
                  let (data, response) = try? await session.data(from: url),
                  let response = response as? HTTPURLResponse, response.statusCode == 200,
                  data.count < 8 * 1024 * 1024, let image = NSImage(data: data) else { return nil }
            try? data.write(to: file, options: .atomic)
            return image
        }
        pending[keyString] = task
        let result = await task.value
        pending.removeValue(forKey: keyString)
        if let result { memory.setObject(result, forKey: cacheKey, cost: 500 * 750 * 4) }
        return result
    }
}
struct PosterView: View {
    let item: MediaItem
    @State private var poster: NSImage?
    @State private var finished = false
    var body: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        if item.isDemo {
                            IllustratedPoster(item: item)
                        } else if let poster {
                            Image(nsImage: poster)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                                .clipped()
                        } else {
                            Rectangle().fill(Color(white: 0.13))
                            VStack(spacing: 12) {
                                if item.posterPath != nil && !finished { ProgressView().controlSize(.small) }
                                else { Image(systemName: "film").font(.system(size: 32)).foregroundStyle(.secondary) }
                                Text(item.title).font(.headline).multilineTextAlignment(.center).padding(.horizontal)
                                Text(finished ? "Poster unavailable" : "Loading poster").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.title) poster\(item.isDemo ? ", original illustrative artwork" : "")")
            .task(id: item.posterPath) {
                finished = false
                if let path = item.posterPath, !item.isDemo { poster = await PosterCache.shared.image(path: path) }
                finished = true
            }
    }
}
struct IllustratedPoster: View {
    let item: MediaItem
    private var color: Color {
        [Color(red: 0.30, green: 0.57, blue: 0.63), Color(red: 0.66, green: 0.42, blue: 0.31), Color(red: 0.73, green: 0.62, blue: 0.34), Color(red: 0.38, green: 0.48, blue: 0.38), Color(red: 0.32, green: 0.44, blue: 0.67)][item.id % 5]
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color(red: 0.07, green: 0.10, blue: 0.12)
                Canvas { context, size in
                    let w = size.width, h = size.height
                    context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .linearGradient(Gradient(colors: [color.opacity(0.45), Color.black]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
                    let circle = CGRect(x: w * 0.16, y: h * 0.12, width: w * 0.68, height: w * 0.68)
                    context.fill(Path(ellipseIn: circle), with: .color(color.opacity(0.85)))
                    switch item.id % 4 {
                    case 0:
                        for i in 0..<8 {
                            let x = CGFloat(i) * w / 7 - w * 0.05
                            let height = h * (0.2 + Double((i * 7 + item.id) % 5) * 0.06)
                            context.fill(Path(CGRect(x: x, y: h * 0.66 - height, width: w * 0.12, height: height)), with: .color(Color.black.opacity(0.85)))
                            for j in 0..<4 { context.fill(Path(CGRect(x: x + w * 0.025, y: h * 0.66 - height + CGFloat(j) * h * 0.04 + 8, width: w * 0.02, height: 2)), with: .color(color.opacity(0.7))) }
                        }
                    case 1:
                        for i in 0..<4 {
                            var ridge = Path(); ridge.move(to: CGPoint(x: -w * 0.2, y: h * 0.65))
                            ridge.addLine(to: CGPoint(x: w * (0.18 + CGFloat(i) * 0.24), y: h * (0.22 + CGFloat(i) * 0.09)))
                            ridge.addLine(to: CGPoint(x: w * 1.3, y: h * 0.7)); ridge.closeSubpath()
                            context.fill(ridge, with: .color(i.isMultiple(of: 2) ? Color.black.opacity(0.6) : color.opacity(0.35)))
                        }
                    case 2:
                        for i in 0..<5 {
                            let inset = CGFloat(i) * w * 0.07
                            context.stroke(Path(ellipseIn: CGRect(x: inset - w * 0.2, y: h * 0.31 + inset * 0.6, width: w * 1.4 - inset * 2, height: w * 0.25)), with: .color(Color.white.opacity(0.12 + Double(i) * 0.05)), lineWidth: 1)
                        }
                        context.fill(Path(CGRect(x: w * 0.47, y: h * 0.37, width: w * 0.07, height: h * 0.27)), with: .color(Color.black.opacity(0.8)))
                    default:
                        for i in 0..<6 {
                            let inset = CGFloat(i) * w * 0.055
                            context.stroke(Path(CGRect(x: w * 0.12 + inset, y: h * 0.15 + inset, width: w * 0.76 - inset * 2, height: h * 0.44 - inset * 2)), with: .color(Color.white.opacity(0.18)), lineWidth: 2)
                        }
                    }
                    for i in 0..<24 {
                        let x = CGFloat((i * 31 + item.id * 7) % 100) / 100 * w
                        let y = CGFloat((i * 17 + item.id * 11) % 100) / 100 * h * 0.62
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.28)))
                    }
                }
                VStack(alignment: .leading, spacing: geo.size.width * 0.045) {
                    Text(item.kind == .movie ? "A TOPMOVIES ILLUSTRATION" : "AN ILLUSTRATIVE SERIES")
                        .font(.system(size: max(7, geo.size.width * 0.035), weight: .medium, design: .monospaced)).tracking(1.4).foregroundStyle(color)
                    Text(item.title.uppercased()).font(.system(size: geo.size.width * 0.095, weight: .semibold, design: .serif)).lineSpacing(0).foregroundStyle(Color(white: 0.94)).fixedSize(horizontal: false, vertical: true)
                    Text("FICTIONAL CATALOG  /  \(item.year)").font(.system(size: max(7, geo.size.width * 0.037), design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.5))
                }.padding(geo.size.width * 0.105)
            }
        }
    }
}
