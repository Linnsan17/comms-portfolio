// usage: boneo_edit <source.mp4> <out.mp4> <poster.jpg> <first post> <second post>
//
// Boneo's reel for the case card (896x752, 30 fps, the middle of each frame):
// the reel as it is, except
// - the purple stretch (17.0-20.1 s), where Facebook ads for two homes slide
//   past one at a time (Gotland, Brösarp, Gotland again). There, two
//   Instagram posts take their places in the same motion: the first post
//   where Brösarp was, the second where Gotland was, each as tall as the ad
//   it replaces. The ads' positions are measured from every frame, so the
//   slide keeps the reel's timing and ease.
// - the collage of screenshots on black after it (20.15-26.27 s, TikTok
//   statistics among them), which is cut, so the purple cuts straight to the
//   coral phone.
import AVFoundation
import AppKit

let args = CommandLine.arguments
let srcURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
let posterURL = URL(fileURLWithPath: args[3])
let postURLs = args[4...5].map { URL(fileURLWithPath: $0) }

let W = 896, H = 752, FPS: Int32 = 60
// written at 30 fps: the reel is 30 fps stored twice over at 60, so every
// other frame is kept (half the decoding for the browser, nothing lost)
let OUT_FPS: Int32 = 30
// the black collage: its first frame is 20.15 s, the coral phone's 26.283 s
let CUT = (from: 20.14, to: 26.275)

// MARK: the reel's purple stretch, in source pixels (1920x1080)

let PURPLE = (r: 128, g: 70, b: 253)
let AD = (top: 108.0, bottom: 972.0, width: 904.0) // every ad's white card
let SPACING = 1824.0 // from one ad's centre to the next

let asset = AVURLAsset(url: srcURL)
let track = asset.tracks(withMediaType: .video).first!

func isPurple(_ p: UnsafePointer<UInt8>, _ bpr: Int, x: Int, y: Int) -> Bool {
  let o = y * bpr + x * 4 // BGRA
  return abs(Int(p[o + 2]) - PURPLE.r) < 14 && abs(Int(p[o + 1]) - PURPLE.g) < 14 && abs(Int(p[o]) - PURPLE.b) < 14
}

/// The ads in a purple frame, as the column runs where their white crosses,
/// and the frame's purple (nil when the frame isn't on the purple)
func adRuns(_ buffer: CVPixelBuffer) -> (runs: [(Double, Double)], purple: CGColor)? {
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
  let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
  let bpr = CVPixelBufferGetBytesPerRow(buffer)
  let p = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
  guard isPurple(p, bpr, x: 8, y: 8), isPurple(p, bpr, x: w - 8, y: h - 8) else { return nil }
  let o = 8 * bpr + 8 * 4
  let purple = CGColor(colorSpace: ctx.colorSpace!, components: [CGFloat(p[o + 2]) / 255, CGFloat(p[o + 1]) / 255, CGFloat(p[o]) / 255, 1])!
  let ys = stride(from: Int(AD.top) + 4, to: Int(AD.bottom) - 4, by: 4).map { $0 }
  var runs: [(Double, Double)] = [], start: Int? = nil
  for x in 0..<w {
    var white = 0
    for y in ys {
      let o = y * bpr + x * 4
      if p[o] > 232 && p[o + 1] > 232 && p[o + 2] > 232 { white += 1 }
    }
    let on = Double(white) / Double(ys.count) > 0.16
    if on && start == nil { start = x }
    if !on, let s = start {
      if x - s > 16 { runs.append((Double(s), Double(x))) }
      start = nil
    }
  }
  if let s = start { runs.append((Double(s), Double(w))) }
  return (runs, purple)
}

/// Where an ad's centre is, from the part of it on screen
func centre(of run: (Double, Double), frameWidth: Double) -> (x: Double, whole: Bool) {
  let (a, b) = run
  if b - a < AD.width - 6 {
    if a <= 0 { return (b - AD.width / 2, false) }
    if b >= frameWidth { return (a + AD.width / 2, false) }
  }
  return ((a + b) / 2, true)
}

// MARK: the frame we draw into

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
ctx.interpolationQuality = .high

let srcSize = track.naturalSize
let scale = CGFloat(H) / srcSize.height
let offsetX = (CGFloat(W) - srcSize.width * scale) / 2

/// The middle of a reel frame, cropped to the card's shape. Its pixels go in
/// as they are, with no colour conversion, and the output is tagged with the
/// reel's own colour (BT.709), so it keeps the reel's colours exactly.
func drawReel(_ buffer: CVPixelBuffer) {
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
  let bpr = CVPixelBufferGetBytesPerRow(buffer), h = CVPixelBufferGetHeight(buffer)
  let bytes = Data(bytes: CVPixelBufferGetBaseAddress(buffer)!, count: bpr * h)
  let image = CGImage(width: CVPixelBufferGetWidth(buffer), height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bpr,
                      space: ctx.colorSpace!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                      provider: CGDataProvider(data: bytes as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
  ctx.draw(image, in: CGRect(x: offsetX, y: 0, width: srcSize.width * scale, height: CGFloat(H)))
}

let posts = postURLs.map { NSImage(contentsOf: $0)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }

/// The purple, and the posts where the ads are: the first post at `first`
/// (the Brösarp ad's centre), the second a spacing either side of it
func drawPosts(first: Double, on purple: CGColor) {
  ctx.setFillColor(purple)
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  for (k, post) in [(-1, posts[1]), (0, posts[0]), (1, posts[1])] {
    let h = CGFloat(AD.bottom - AD.top), w = h * CGFloat(post.width) / CGFloat(post.height)
    let cx = CGFloat(first + SPACING * Double(k))
    // source pixels (y down) to the card's frame (y up)
    let rect = CGRect(x: offsetX + (cx - w / 2) * scale, y: CGFloat(H) - CGFloat(AD.bottom) * scale, width: w * scale, height: h * scale)
    guard rect.maxX > 0, rect.minX < CGFloat(W) else { continue }
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.clip()
    ctx.draw(post, in: rect)
    ctx.restoreGState()
  }
}

// MARK: writing

try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 30],
  AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2, AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2, AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
var written = 0
var tick = 0 // frames offered, at 60 fps
let data = ctx.data!.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * H)

func emit() {
  tick += 1
  if tick % 2 == 0 { return }
  while !input.isReadyForMoreMediaData { usleep(2000) }
  var pb: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
  CVPixelBufferLockBaseAddress(pb!, [])
  let dst = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
  let dbpr = CVPixelBufferGetBytesPerRow(pb!)
  for y in 0..<H { memcpy(dst + y * dbpr, data + y * ctx.bytesPerRow, W * 4) }
  CVPixelBufferUnlockBaseAddress(pb!, [])
  // already the reel's BT.709 colour, so the encoder leaves it as it is
  CVBufferSetAttachment(pb!, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
  CVBufferSetAttachment(pb!, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
  CVBufferSetAttachment(pb!, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
  adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(written), timescale: OUT_FPS))
  if written == Int(OUT_FPS) / 2 { // the poster: half a second in
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])!.write(to: posterURL)
  }
  written += 1
}

let reader = try! AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
output.alwaysCopiesSampleData = false
reader.add(output)
reader.startReading()
var first: Double? = nil // the Brösarp ad's centre, followed frame to frame
var replaced = 0
while let sample = output.copyNextSampleBuffer() {
  guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
  let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
  if time >= CUT.from && time < CUT.to { continue }
  if let (runs, purple) = adRuns(buffer), !runs.isEmpty {
    let width = Double(CVPixelBufferGetWidth(buffer))
    let seen = runs.map { centre(of: $0, frameWidth: width) }
    if first == nil {
      // the stretch opens with Gotland leaving and Brösarp coming in on the right
      first = seen.map(\.x).max()!
    } else {
      // whichever ad it is, the Brösarp centre it implies nearest the last one,
      // trusting an ad that's wholly on screen over one cut by the edge
      let guesses = seen.flatMap { s in [-1.0, 0, 1].map { (x: s.x - SPACING * $0, whole: s.whole) } }
      let best = guesses.min { a, b in
        let da = abs(a.x - first!) + (a.whole ? 0 : 40), db = abs(b.x - first!) + (b.whole ? 0 : 40)
        return da < db
      }!
      first = best.x
    }
    drawPosts(first: first!, on: purple)
    replaced += 1
  } else {
    drawReel(buffer)
  }
  emit()
}
print("posts drawn over", replaced, "frames; total", Double(written) / Double(OUT_FPS), "s")

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { fatalError("write failed: \(String(describing: writer.error))") }
let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
print("\(outURL.lastPathComponent): \(size / 1024) KB")
