// usage: svedea_edit <source.mp4> <post.png> <out.mp4> <poster.jpg> [debug dir]
//
// Re-edits Svedea's reel for the case card (896x752, 30 fps):
//   1. the opening: the Bosch competition phone, as it is
//   2. a second phone: the same fly-in, mirrored, with the homeless
//      animals' day post warped onto its screen
//   3. the rest of the reel, with its white background turned Svedea blue,
//      leaving out 28.75-34.3 s (the wind turbine and the forest)
import AVFoundation
import AppKit
import CoreImage

let args = CommandLine.arguments
let srcURL = URL(fileURLWithPath: args[1])
let postURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
let posterURL = URL(fileURLWithPath: args[4])
let debugDir: URL? = args.count > 5 ? URL(fileURLWithPath: args[5]) : nil
if let debugDir { try? FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true) }

let W = 896, H = 752
let BG = (r: 0, g: 80, b: 115) // the reel's blue

// MARK: reading

let asset = AVURLAsset(url: srcURL)
let track = asset.tracks(withMediaType: .video).first!
let ciContext = CIContext(options: [.cacheIntermediates: false])

func readFrames(from start: Double, to end: Double, _ body: (Double, CGImage) -> Bool) {
  let reader = try! AVAssetReader(asset: asset)
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  output.alwaysCopiesSampleData = false
  reader.add(output)
  reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 6000), end: CMTime(seconds: end, preferredTimescale: 6000))
  reader.startReading()
  while let sample = output.copyNextSampleBuffer() {
    guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    let image = CIImage(cvPixelBuffer: buffer)
    guard let cg = ciContext.createCGImage(image, from: image.extent) else { continue }
    if !body(t, cg) { reader.cancelReading(); break }
  }
}

// MARK: a frame we can draw into and edit pixel by pixel (BGRA in memory)

final class Canvas {
  let ctx: CGContext
  let d: UnsafeMutablePointer<UInt8>
  let bpr: Int
  init() {
    ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.interpolationQuality = .high
    bpr = ctx.bytesPerRow
    d = ctx.data!.bindMemory(to: UInt8.self, capacity: bpr * H)
  }
  /// The middle of the frame, cropped to the card's shape
  func draw(_ image: CGImage, mirror: Bool) {
    let s = CGFloat(H) / CGFloat(image.height)
    let dw = CGFloat(image.width) * s
    ctx.saveGState()
    if mirror { ctx.translateBy(x: CGFloat(W), y: 0); ctx.scaleBy(x: -1, y: 1) }
    ctx.draw(image, in: CGRect(x: (CGFloat(W) - dw) / 2, y: 0, width: dw, height: CGFloat(H)))
    ctx.restoreGState()
  }
  @inline(__always) func i(_ x: Int, _ y: Int) -> Int { y * bpr + x * 4 }
  @inline(__always) func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
    let p = i(x, y); return (Int(d[p + 2]), Int(d[p + 1]), Int(d[p]))
  }
  @inline(__always) func set(_ x: Int, _ y: Int, _ r: Int, _ g: Int, _ b: Int) {
    let p = i(x, y)
    d[p] = UInt8(max(0, min(255, b))); d[p + 1] = UInt8(max(0, min(255, g))); d[p + 2] = UInt8(max(0, min(255, r))); d[p + 3] = 255
  }
  func isBlue(_ x: Int, _ y: Int) -> Bool {
    let (r, g, b) = rgb(x, y); return abs(r - BG.r) + abs(g - BG.g) + abs(b - BG.b) < 40
  }
}

// MARK: white background to blue

func blueBackground(_ c: Canvas) {
  @inline(__always) func white(_ x: Int, _ y: Int) -> Bool {
    let (r, g, b) = c.rgb(x, y); return r >= 244 && g >= 244 && b >= 244
  }
  // only frames that sit on white: a third of the edge or more is white
  var border = 0, whiteBorder = 0
  for x in stride(from: 0, to: W, by: 3) { for y in [0, H - 1] { border += 1; if white(x, y) { whiteBorder += 1 } } }
  for y in stride(from: 0, to: H, by: 3) { for x in [0, W - 1] { border += 1; if white(x, y) { whiteBorder += 1 } } }
  if Double(whiteBorder) < Double(border) * 0.3 { return }

  // flood the white in from the edges
  var filled = [Bool](repeating: false, count: W * H)
  var stack: [Int] = []
  func seed(_ x: Int, _ y: Int) { if !filled[y * W + x] && white(x, y) { filled[y * W + x] = true; stack.append(y * W + x) } }
  for x in 0..<W { seed(x, 0); seed(x, H - 1) }
  for y in 0..<H { seed(0, y); seed(W - 1, y) }
  while let k = stack.popLast() {
    let x = k % W, y = k / W
    c.set(x, y, BG.r, BG.g, BG.b)
    if x > 0 { seed(x - 1, y) }
    if x < W - 1 { seed(x + 1, y) }
    if y > 0 { seed(x, y - 1) }
    if y < H - 1 { seed(x, y + 1) }
  }
  // soften the light fringe along the edges of what sits on it: a pixel
  // within 2px of the background, as light as it is, was that much white
  var near = [Bool](repeating: false, count: W * H)
  for y in 0..<H { for x in 0..<W where filled[y * W + x] {
    for dy in -2...2 { for dx in -2...2 {
      let nx = x + dx, ny = y + dy
      if nx >= 0 && nx < W && ny >= 0 && ny < H { near[ny * W + nx] = true }
    } }
  } }
  for y in 0..<H { for x in 0..<W where near[y * W + x] && !filled[y * W + x] {
    let (r, g, b) = c.rgb(x, y)
    let m = min(r, min(g, b))
    if m <= 150 { continue }
    let a = Double(m - 150) / 105
    c.set(x, y, r + Int(a * Double(BG.r - 255)), g + Int(a * Double(BG.g - 255)), b + Int(a * Double(BG.b - 255)))
  } }
}

// MARK: finding the phone's screen

struct Line { var a: Double, b: Double } // x = a*y + b (sides) or y = a*x + b (top, bottom)
func fit(_ pts: [(Double, Double)]) -> Line? { // fits second = a*first + b
  guard pts.count >= 4 else { return nil }
  let n = Double(pts.count)
  let sx = pts.reduce(0) { $0 + $1.0 }, sy = pts.reduce(0) { $0 + $1.1 }
  let sxx = pts.reduce(0) { $0 + $1.0 * $1.0 }, sxy = pts.reduce(0) { $0 + $1.0 * $1.1 }
  let den = n * sxx - sx * sx
  if abs(den) < 1e-9 { return nil }
  let a = (n * sxy - sx * sy) / den
  return Line(a: a, b: (sy - a * sx) / n)
}
// side line x = s.a*y + s.b meets edge line y = e.a*x + e.b
func meet(side s: Line, edge e: Line) -> CGPoint {
  let y = (e.a * s.b + e.b) / (1 - e.a * s.a)
  return CGPoint(x: s.a * y + s.b, y: y)
}

struct Found { var left: Line?, right: Line?, top: Line?, bottom: Line?; var width = 0; var box = CGRect.zero }

func findScreen(_ c: Canvas) -> Found {
  var f = Found()
  var minX = W, maxX = -1, minY = H, maxY = -1
  for y in 0..<H { for x in 0..<W where !c.isBlue(x, y) {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
  } }
  let w = maxX - minX
  f.width = max(0, w)
  if w > 0 { f.box = CGRect(x: minX, y: minY, width: w, height: maxY - minY) }
  if w < 30 { return f }
  func white(_ x: Int, _ y: Int) -> Bool {
    let (r, g, b) = c.rgb(x, y)
    return r > 200 && g > 200 && b > 200 && max(r, max(g, b)) - min(r, min(g, b)) < 35
  }
  // the first of four white pixels in a row, walking from (x, y) by (dx, dy)
  func firstWhite(_ x0: Int, _ y0: Int, _ dx: Int, _ dy: Int, _ steps: Int) -> Int? {
    var run = 0
    for s in 0..<steps {
      let x = x0 + dx * s, y = y0 + dy * s
      if x < 0 || x >= W || y < 0 || y >= H { return nil }
      if white(x, y) { run += 1; if run == 4 { return s - 3 } } else { run = 0 }
    }
    return nil
  }
  let cols = stride(from: 0.2, through: 0.32, by: 0.02).map { $0 } + stride(from: 0.68, through: 0.8, by: 0.02).map { $0 }
  let h = maxY - minY
  if minY > 2 {
    var pts: [(Double, Double)] = []
    for fr in cols { let x = minX + Int(fr * Double(w)); if let s = firstWhite(x, minY, 0, 1, h / 2) { pts.append((Double(x), Double(minY + s))) } }
    f.top = fit(pts)
  }
  if maxY < H - 3 {
    var pts: [(Double, Double)] = []
    for fr in cols { let x = minX + Int(fr * Double(w)); if let s = firstWhite(x, maxY, 0, -1, h / 2) { pts.append((Double(x), Double(maxY - s))) } }
    f.bottom = fit(pts)
  }
  // the sides, along the white bands at the top (status bar and page header)
  // and the bottom (tab bar) of the post
  var rows: [Int] = []
  if let top = f.top {
    let y0 = Int(top.a * Double(minX + w / 2) + top.b)
    rows += stride(from: y0 + 6, to: min(maxY, y0 + 6 + Int(0.16 * Double(h))), by: 3).map { $0 }
  }
  if let bottom = f.bottom {
    let y1 = Int(bottom.a * Double(minX + w / 2) + bottom.b)
    rows += stride(from: max(minY, y1 - Int(0.1 * Double(h))), to: y1 - 5, by: 3).map { $0 }
  }
  var lp: [(Double, Double)] = [], rp: [(Double, Double)] = []
  for y in rows where y > 0 && y < H {
    if let s = firstWhite(minX, y, 1, 0, w / 2) { lp.append((Double(y), Double(minX + s))) }
    if let s = firstWhite(maxX, y, -1, 0, w / 2) { rp.append((Double(y), Double(maxX - s))) }
  }
  f.left = fit(lp); f.right = fit(rp)
  return f
}

struct Quad { var tl, tr, br, bl: CGPoint }

// MARK: drawing the post onto the screen

let post: (w: Int, h: Int, px: [UInt8]) = {
  let img = NSImage(contentsOf: postURL)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  let w = img.width, h = img.height
  var px = [UInt8](repeating: 0, count: w * h * 4)
  let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
  return (w, h, px)
}()

func samplePost(_ u: Double, _ v: Double) -> (Double, Double, Double) {
  let x = min(max(u * Double(post.w - 1), 0), Double(post.w - 1))
  let y = min(max(v * Double(post.h - 1), 0), Double(post.h - 1))
  let x0 = Int(x), y0 = Int(y), x1 = min(x0 + 1, post.w - 1), y1 = min(y0 + 1, post.h - 1)
  let fx = x - Double(x0), fy = y - Double(y0)
  func p(_ x: Int, _ y: Int, _ ch: Int) -> Double { Double(post.px[(y * post.w + x) * 4 + ch]) }
  var out = [0.0, 0.0, 0.0]
  for ch in 0..<3 {
    out[ch] = (p(x0, y0, ch) * (1 - fx) + p(x1, y0, ch) * fx) * (1 - fy) + (p(x0, y1, ch) * (1 - fx) + p(x1, y1, ch) * fx) * fy
  }
  return (out[0], out[1], out[2])
}

// the screen's shape in its own 0-1 coordinates: rounded corners, and the
// Dynamic Island, which the mockup draws itself
let screenAspect = Double(post.w) / Double(post.h)
func inScreen(_ u: Double, _ v: Double) -> Bool {
  let mu = 0.006, mv = 0.004
  if u < -mu || u > 1 + mu || v < -mv || v > 1 + mv { return false }
  let ru = 0.14, rv = 0.14 * screenAspect
  let cu = u < ru ? ru : (u > 1 - ru ? 1 - ru : u)
  let cv = v < rv ? rv : (v > 1 - rv ? 1 - rv : v)
  let du = (u - cu) / (ru + mu), dv = (v - cv) / (rv + mv)
  return du * du + dv * dv <= 1
}
func inIsland(_ u: Double, _ v: Double) -> Bool {
  let top = 0.0135, bottom = 0.0565, rv = (bottom - top) / 2, ru = rv / screenAspect
  let left = 0.34, right = 0.66
  if v < top || v > bottom || u < left || u > right { return false }
  let cu = min(max(u, left + ru), right - ru), cv = top + rv
  let du = (u - cu) / ru, dv = (v - cv) / rv
  return du * du + dv * dv <= 1
}

/// Maps the unit square onto the quad (Heckbert); returns the inverse
func inverseHomography(_ q: Quad) -> [Double] {
  let x0 = Double(q.tl.x), y0 = Double(q.tl.y), x1 = Double(q.tr.x), y1 = Double(q.tr.y)
  let x2 = Double(q.br.x), y2 = Double(q.br.y), x3 = Double(q.bl.x), y3 = Double(q.bl.y)
  let sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3
  let dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2
  let den = dx1 * dy2 - dx2 * dy1
  let g = (sx * dy2 - dx2 * sy) / den, h = (dx1 * sy - sx * dy1) / den
  let a = x1 - x0 + g * x1, b = x3 - x0 + h * x3, c = x0
  let d = y1 - y0 + g * y1, e = y3 - y0 + h * y3, f = y0
  // inverse of [[a b c][d e f][g h 1]]
  let A = e - f * h, B = f * g - d, C = d * h - e * g
  let D = c * h - b, E = a - c * g, F = b * g - a * h
  let G = b * f - c * e, Hh = c * d - a * f, I = a * e - b * d
  return [A, D, G, B, E, Hh, C, F, I]
}

func drawPost(_ c: Canvas, _ q: Quad) {
  // the phone, shrunk by 4px, so the post never spills off it
  var phone = [Bool](repeating: false, count: W * H)
  for y in 0..<H { for x in 0..<W { phone[y * W + x] = !c.isBlue(x, y) } }
  var inside = phone
  for y in 0..<H { for x in 0..<W where phone[y * W + x] {
    search: for dy in -4...4 { for dx in -4...4 {
      let nx = x + dx, ny = y + dy
      if nx < 0 || nx >= W || ny < 0 || ny >= H { continue }
      if !phone[ny * W + nx] { inside[y * W + x] = false; break search }
    } }
  } }
  let m = inverseHomography(q)
  let xs = [q.tl.x, q.tr.x, q.br.x, q.bl.x], ys = [q.tl.y, q.tr.y, q.br.y, q.bl.y]
  let x0 = max(0, Int(xs.min()!) - 3), x1 = min(W - 1, Int(xs.max()!) + 3)
  let y0 = max(0, Int(ys.min()!) - 3), y1 = min(H - 1, Int(ys.max()!) + 3)
  if x0 >= x1 || y0 >= y1 { return }
  let subs: [(Double, Double)] = [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)]
  for y in y0...y1 { for x in x0...x1 where inside[y * W + x] {
    var n = 0.0, r = 0.0, g = 0.0, b = 0.0
    for (ox, oy) in subs {
      let px = Double(x) + ox, py = Double(y) + oy
      let w = m[6] * px + m[7] * py + m[8]
      let u = (m[0] * px + m[1] * py + m[2]) / w, v = (m[3] * px + m[4] * py + m[5]) / w
      if !inScreen(u, v) { continue }
      n += 1
      if inIsland(u, v) { continue } // black
      let s = samplePost(u, v); r += s.0; g += s.1; b += s.2
    }
    if n == 0 { continue }
    let cov = n / 4
    let (or, og, ob) = c.rgb(x, y)
    c.set(x, y, Int(Double(or) * (1 - cov) + r / 4), Int(Double(og) * (1 - cov) + g / 4), Int(Double(ob) * (1 - cov) + b / 4))
  } }
}

// MARK: writing

try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 30],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
var written = 0

func save(_ c: Canvas, _ url: URL, quality: Double = 0.85) {
  let rep = NSBitmapImageRep(cgImage: c.ctx.makeImage()!)
  try! rep.representation(using: .jpeg, properties: [.compressionFactor: quality])!.write(to: url)
}

func emit(_ c: Canvas, _ label: String) {
  while !input.isReadyForMoreMediaData { usleep(2000) }
  var pb: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
  CVPixelBufferLockBaseAddress(pb!, [])
  let dst = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
  let dbpr = CVPixelBufferGetBytesPerRow(pb!)
  for y in 0..<H { memcpy(dst + y * dbpr, c.d + y * c.bpr, W * 4) }
  CVPixelBufferUnlockBaseAddress(pb!, [])
  adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(written), timescale: 30))
  if written == 15 { save(c, posterURL, quality: 0.8) }
  if let debugDir, written % 10 == 0 { save(c, debugDir.appendingPathComponent(String(format: "o_%04d_%@.jpg", written, label))) }
  written += 1
}

let canvas = Canvas()

// 1. the Bosch phone, until the reel cuts to white
var kept = 0
readFrames(from: 0, to: 7.4) { _, img in
  canvas.draw(img, mirror: false)
  if !canvas.isBlue(4, 4) { return false }
  if kept % 2 == 0 { emit(canvas, "bosch") }
  kept += 1
  return true
}
print("bosch frames", written)

// 2. the second phone: find its screen in every frame first, then draw
var found: [Found] = []
kept = 0
readFrames(from: 0.6, to: 7.4) { _, img in
  canvas.draw(img, mirror: true)
  if !canvas.isBlue(4, 4) { return false }
  if kept % 2 == 0 { found.append(findScreen(canvas)) }
  kept += 1
  return true
}
// the screen's height where both edges show, for frames where one is cut off
var heights: [Int: Double] = [:]
for (k, f) in found.enumerated() {
  if let l = f.left, let r = f.right, let t = f.top, let b = f.bottom {
    let hl = meet(side: l, edge: b).y - meet(side: l, edge: t).y, hr = meet(side: r, edge: b).y - meet(side: r, edge: t).y
    heights[k] = Double(hl + hr) / 2
  }
}
func height(near k: Int) -> Double? {
  heights.min { abs($0.key - k) < abs($1.key - k) }?.value
}
// Where the whole screen shows, its four edges give the corners. Where the
// phone is half out of the frame, the sides are measured over a short band,
// so only the corners next to that band are sure: the other two come from
// the nearest whole screen, the same distance and direction away.
var whole: [Int: Quad] = [:]
for (k, f) in found.enumerated() {
  if let l = f.left, let r = f.right, let t = f.top, let b = f.bottom {
    whole[k] = Quad(tl: meet(side: l, edge: t), tr: meet(side: r, edge: t), br: meet(side: r, edge: b), bl: meet(side: l, edge: b))
  }
}
func nearestWhole(_ k: Int) -> Quad? { whole.min { abs($0.key - k) < abs($1.key - k) }?.value }
func minus(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
func plus(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
var quads: [Quad?] = found.enumerated().map { k, f in
  if let q = whole[k] { return q }
  guard let l = f.left, let r = f.right, let ref = nearestWhole(k) else { return nil }
  if let t = f.top {
    let tl = meet(side: l, edge: t), tr = meet(side: r, edge: t)
    return Quad(tl: tl, tr: tr, br: plus(tr, minus(ref.br, ref.tr)), bl: plus(tl, minus(ref.bl, ref.tl)))
  }
  if let b = f.bottom {
    let bl = meet(side: l, edge: b), br = meet(side: r, edge: b)
    return Quad(tl: minus(bl, minus(ref.bl, ref.tl)), tr: minus(br, minus(ref.br, ref.tr)), br: br, bl: bl)
  }
  return nil
}
// a quad that doesn't fit the phone's outline is a misread: drop it
for k in quads.indices {
  guard let q = quads[k] else { continue }
  let box = found[k].box.insetBy(dx: -24, dy: -24)
  let top = hypot(q.tr.x - q.tl.x, q.tr.y - q.tl.y), bottom = hypot(q.br.x - q.bl.x, q.br.y - q.bl.y)
  let xs = [q.tl.x, q.tr.x, q.br.x, q.bl.x]
  let fits = xs.min()! >= box.minX && xs.max()! <= box.maxX && top > 0 && bottom > 0
    && max(top, bottom) / min(top, bottom) < 1.5 && q.tl.x < q.tr.x && q.bl.x < q.br.x
  if !fits { quads[k] = nil }
}
// a quad far from where its neighbours put it is a misread: drop it
func mid(_ a: Quad, _ b: Quad) -> Quad {
  func m(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2) }
  return Quad(tl: m(a.tl, b.tl), tr: m(a.tr, b.tr), br: m(a.br, b.br), bl: m(a.bl, b.bl))
}
func off(_ p: Quad, _ r: Quad) -> CGFloat {
  [abs(p.tl.x - r.tl.x), abs(p.tl.y - r.tl.y), abs(p.tr.x - r.tr.x), abs(p.tr.y - r.tr.y),
   abs(p.br.x - r.br.x), abs(p.br.y - r.br.y), abs(p.bl.x - r.bl.x), abs(p.bl.y - r.bl.y)].max()!
}
for k in 1..<max(1, quads.count - 1) {
  guard let q = quads[k], let a = quads[k - 1], let b = quads[k + 1] else { continue }
  if off(q, mid(a, b)) > 30 { quads[k] = nil }
}
// fill gaps from the frames either side
func lerp(_ a: Quad, _ b: Quad, _ t: CGFloat) -> Quad {
  func l(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t) }
  return Quad(tl: l(a.tl, b.tl), tr: l(a.tr, b.tr), br: l(a.br, b.br), bl: l(a.bl, b.bl))
}
// As the phone flies in and out it spins, and the screen is too thin to
// read: there the last good screen follows the phone's outline instead,
// squeezed with its width and moved with the edge still in the frame (its
// top flying in, its bottom flying out), up to the frame where the phone
// is edge-on. Past that it shows its back.
func follow(_ q: Quad, from a: CGRect, to b: CGRect, anchorTop: Bool) -> Quad {
  let sx = b.width / max(a.width, 1), dy = anchorTop ? b.minY - a.minY : b.maxY - a.maxY
  func m(_ p: CGPoint) -> CGPoint { CGPoint(x: b.minX + (p.x - a.minX) * sx, y: p.y + dy) }
  return Quad(tl: m(q.tl), tr: m(q.tr), br: m(q.br), bl: m(q.bl))
}
let known = quads.indices.filter { quads[$0] != nil }
if let first = known.first, let last = known.last {
  for k in first...last where quads[k] == nil {
    let a = known.last { $0 < k }!, b = known.first { $0 > k }!
    quads[k] = lerp(quads[a]!, quads[b]!, CGFloat(k - a) / CGFloat(b - a))
  }
  if last + 1 < quads.count {
    let edgeOn = ((last + 1)..<quads.count).min { found[$0].width < found[$1].width }!
    for k in (last + 1)..<edgeOn where found[k].width >= 30 {
      quads[k] = follow(quads[last]!, from: found[last].box, to: found[k].box, anchorTop: false)
    }
  }
  if first > 0 {
    let edgeOn = (0..<first).min { found[$0].width < found[$1].width }!
    for k in (edgeOn + 1)..<first where found[k].width >= 30 {
      quads[k] = follow(quads[first]!, from: found[first].box, to: found[k].box, anchorTop: true)
    }
  }
}
// steady the corners: each one a quarter toward each neighbour
let raw = quads
for k in 1..<max(1, quads.count - 1) {
  guard let q = raw[k], let a = raw[k - 1], let b = raw[k + 1] else { continue }
  let n = mid(a, b)
  func s(_ p: CGPoint, _ m: CGPoint) -> CGPoint { CGPoint(x: (p.x + m.x) / 2, y: (p.y + m.y) / 2) }
  quads[k] = Quad(tl: s(q.tl, n.tl), tr: s(q.tr, n.tr), br: s(q.br, n.br), bl: s(q.bl, n.bl))
}
print("second phone frames", found.count, "screens found", quads.compactMap { $0 }.count)
if ProcessInfo.processInfo.environment["SV_TRACE"] != nil {
  for (k, f) in found.enumerated() {
    let q = quads[k]
    print(k, "w", f.width, "L", f.left != nil, "R", f.right != nil, "T", f.top != nil, "B", f.bottom != nil, "h", heights[k].map { Int($0) } ?? -1,
          q.map { "tl \(Int($0.tl.x)),\(Int($0.tl.y)) br \(Int($0.br.x)),\(Int($0.br.y))" } ?? "-")
  }
}
kept = 0
var k = 0
readFrames(from: 0.6, to: 7.4) { _, img in
  canvas.draw(img, mirror: true)
  if !canvas.isBlue(4, 4) { return false }
  if kept % 2 == 0 {
    if k < quads.count, let q = quads[k] { drawPost(canvas, q) }
    emit(canvas, "shelter")
    k += 1
  }
  kept += 1
  return true
}
print("after second phone", written)

// 3. the rest, on blue, without 28.75-34.3 s
for (start, end) in [(7.0, 28.775), (34.3, 36.0)] {
  kept = 0
  var started = start > 30
  readFrames(from: start, to: end) { _, img in
    canvas.draw(img, mirror: false)
    if !started { if canvas.isBlue(4, 4) { return true }; started = true }
    if kept % 2 == 0 { blueBackground(canvas); emit(canvas, "rest") }
    kept += 1
    return true
  }
}
print("total frames", written, "seconds", Double(written) / 30)

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }
let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
print("\(outURL.lastPathComponent): \(size / 1024) KB")
