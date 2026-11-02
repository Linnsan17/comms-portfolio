// usage: phone_track <reel.mp4> <from s> <to s> > track.txt
//
// Follows a phone on a white background through a reel, frame by frame: the
// straight middle part of each side of its silhouette, fitted as a line
// (left and right as x = a*y + b, top and bottom as y = c*x + d, in the
// reel's pixels from the top left). A side that runs off the frame is "-".
// Used for Svedea's toilet-roll phone (svedea_edit.swift puts another part
// of the clip on its screen).
import AVFoundation

let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let from = Double(args[2])!, to = Double(args[3])!
let track = asset.tracks(withMediaType: .video).first!
let reader = try! AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
reader.timeRange = CMTimeRange(start: CMTime(seconds: from, preferredTimescale: 6000), end: CMTime(seconds: to, preferredTimescale: 6000))
reader.startReading()

/// Least squares v = s*u + k, then again without the points that stick out
/// on the outside (the side buttons), twice
func fit(_ pts: [(u: Double, v: Double)], outside: Double) -> (s: Double, k: Double)? {
  var p = pts
  var line: (s: Double, k: Double)? = nil
  for _ in 0..<3 {
    guard p.count > 20 else { return line }
    let n = Double(p.count)
    let su = p.reduce(0) { $0 + $1.u }, sv = p.reduce(0) { $0 + $1.v }
    let suu = p.reduce(0) { $0 + $1.u * $1.u }, suv = p.reduce(0) { $0 + $1.u * $1.v }
    let s = (n * suv - su * sv) / (n * suu - su * su)
    let k = (sv - s * su) / n
    line = (s, k)
    // outside = -1: the outside is towards smaller v (left, top)
    p = p.filter { ($0.v - (s * $0.u + k)) * outside < 0.75 }
  }
  return line
}

print("# frame time | left a,b | right a,b | top c,d | bottom c,d  (x = a*y + b, y = c*x + d)")
while let sample = output.copyNextSampleBuffer() {
  guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
  let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer), bpr = CVPixelBufferGetBytesPerRow(buffer)
  let px = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
  func dark(_ x: Int, _ y: Int) -> Bool {
    let o = y * bpr + x * 4
    return min(px[o], px[o + 1], px[o + 2]) < 225
  }
  // the background must be white (the shot before is blue)
  let white = !dark(20, 20) && !dark(w - 20, h - 20) && !dark(20, h - 20) && !dark(w - 20, 20)
  var rows: [(y: Int, l: Int, r: Int)] = [], cols: [(x: Int, t: Int, b: Int)] = []
  if white {
    for y in stride(from: 0, to: h, by: 2) {
      var l = -1, r = -1
      for x in 300..<(w - 300) where dark(x, y) { if l < 0 { l = x }; r = x }
      if l >= 0 && r - l > 60 { rows.append((y, l, r)) }
    }
    for x in stride(from: 300, to: w - 300, by: 2) {
      var t = -1, b = -1
      for y in 0..<h where dark(x, y) { if t < 0 { t = y }; b = y }
      if t >= 0 && b - t > 60 { cols.append((x, t, b)) }
    }
  }
  CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
  let frame = Int((time * 60).rounded())
  guard rows.count > 40, cols.count > 40 else {
    print(frame, String(format: "%.4f", time), "| none")
    continue
  }
  // the straight middle of each side: away from the rounded corners
  let top = rows.first!.y, bottom = rows.last!.y
  let left = cols.first!.x, right = cols.last!.x
  let vh = Double(bottom - top), vw = Double(right - left)
  let midRows = rows.filter { Double($0.y - top) > vh * 0.22 && Double(bottom - $0.y) > vh * 0.22 }
  let midCols = cols.filter { Double($0.x - left) > vw * 0.25 && Double(right - $0.x) > vw * 0.25 }
  let L = fit(midRows.map { (Double($0.y), Double($0.l)) }, outside: -1)
  let R = fit(midRows.map { (Double($0.y), Double($0.r)) }, outside: 1)
  // top and bottom only where the phone doesn't run off the frame there
  let topCut = midCols.contains { $0.t <= 1 }, bottomCut = midCols.contains { $0.b >= h - 2 }
  let T = topCut ? nil : fit(midCols.map { (Double($0.x), Double($0.t)) }, outside: -1)
  let B = bottomCut ? nil : fit(midCols.map { (Double($0.x), Double($0.b)) }, outside: 1)
  func show(_ l: (s: Double, k: Double)?) -> String { l.map { String(format: "%.6f,%.3f", $0.s, $0.k) } ?? "-" }
  print(frame, String(format: "%.4f", time), "|", show(L), "|", show(R), "|", show(T), "|", show(B))
}
