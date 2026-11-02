// Export the CV to an A4 PDF with WebKit (Safari's engine), one page
// per .sheet.
//
// usage: swiftc -O cv/export_pdf.swift -o /tmp/export_pdf
//        /tmp/export_pdf http://localhost:8796/cv/ assets/cv.pdf
//
// Chrome's print to PDF turns OpenType fonts with CFF outlines (the
// PP Mori .otf files) into Type 3 outlines, so text copied or parsed
// out of its PDF comes apart ("Dr ive n"). WebKit embeds the fonts as
// fonts, so the text reads back as written. WebKit's PDF has one point
// per CSS pixel, so each sheet comes out 794 × 1123 pt; it's scaled to
// A4 afterwards (laying the page out zoomed instead changes the line
// breaks), and its email and phone links are copied over. It stops with
// an error if WebKit's line breaks push text past the bottom of a sheet.

import AppKit
import PDFKit
import WebKit

let args = CommandLine.arguments
guard args.count == 3, let pageURL = URL(string: args[1]) else {
  print("usage: export_pdf <url> <out.pdf>")
  exit(2)
}
let outURL = URL(fileURLWithPath: args[2])

func fail(_ message: String) -> Never {
  print(message)
  exit(1)
}

final class Exporter: NSObject, WKNavigationDelegate {
  let pageURL: URL
  let outURL: URL
  let window = NSWindow(contentRect: NSRect(x: -20000, y: 0, width: 1100, height: 3000),
                        styleMask: [.borderless], backing: .buffered, defer: false)
  let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 3000))
  var pages: [Data] = []

  init(pageURL: URL, outURL: URL) {
    self.pageURL = pageURL
    self.outURL = outURL
  }

  func start() {
    web.navigationDelegate = self
    window.contentView = web
    window.orderBack(nil)
    web.load(URLRequest(url: pageURL, cachePolicy: .reloadIgnoringLocalCacheData))
  }

  // Each sheet's box, and how close its lowest text comes to the bottom
  // edge (the sheet's padding is the margin it should keep). The sheets
  // are first stacked flush at the left edge, so no box starts on a
  // fraction of a pixel and leaves a white sliver at the page's edge.
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let measure = """
      const flush = document.createElement("style");
      flush.textContent = ".cv-bar { display: none } .sheet { margin: 0 !important; outline: 0 !important }";
      document.head.append(flush);
      await document.fonts.ready;
      await Promise.all([...document.images].map(i => i.decode().catch(() => {})));
      return [...document.querySelectorAll(".sheet")].map(s => {
        const r = s.getBoundingClientRect();
        const pad = parseFloat(getComputedStyle(s).paddingBottom);
        const lowest = Math.max(...[...s.querySelectorAll("p, li, dd, img")].map(e => e.getBoundingClientRect().bottom));
        return [r.left + scrollX, r.top + scrollY, r.width, r.height, r.bottom - lowest - pad];
      });
      """
    webView.callAsyncJavaScript(measure, arguments: [:], in: nil, in: .page) { result in
      guard case .success(let value) = result, let sheets = value as? [[Double]], !sheets.isEmpty else {
        fail("could not measure the sheets: \(result)")
      }
      for (i, s) in sheets.enumerated() where s[4] < 0 {
        fail(String(format: "sheet %d: text runs %.1f mm into the bottom margin", i + 1, -s[4] * 25.4 / 96))
      }
      self.export(sheets, from: 0)
    }
  }

  func export(_ sheets: [[Double]], from index: Int) {
    guard index < sheets.count else {
      finish()
      return
    }
    let s = sheets[index]
    let config = WKPDFConfiguration()
    config.rect = CGRect(x: s[0], y: s[1], width: s[2], height: s[3])
    web.createPDF(configuration: config) { result in
      guard case .success(let data) = result else {
        fail("createPDF failed for sheet \(index + 1): \(result)")
      }
      self.pages.append(data)
      self.export(sheets, from: index + 1)
    }
  }

  // Scale every page to A4, then put the links back on top
  func finish() {
    var a4 = CGRect(x: 0, y: 0, width: 595.2756, height: 841.8898)
    guard let ctx = CGContext(outURL as CFURL, mediaBox: &a4, nil) else {
      fail("could not create \(outURL.path)")
    }
    var links: [[(CGRect, URL)]] = []
    for data in pages {
      guard let provider = CGDataProvider(data: data as CFData),
            let page = CGPDFDocument(provider)?.page(at: 1),
            let kitPage = PDFDocument(data: data)?.page(at: 0) else {
        fail("could not read WebKit's PDF")
      }
      let src = page.getBoxRect(.mediaBox)
      let sx = a4.width / src.width
      let sy = a4.height / src.height
      ctx.beginPDFPage(nil)
      ctx.scaleBy(x: sx, y: sy)
      ctx.translateBy(x: -src.minX, y: -src.minY)
      ctx.drawPDFPage(page)
      ctx.endPDFPage()
      links.append(kitPage.annotations.compactMap { a in
        guard let url = a.url ?? (a.action as? PDFActionURL)?.url else { return nil }
        let b = a.bounds
        return (CGRect(x: (b.minX - src.minX) * sx, y: (b.minY - src.minY) * sy,
                       width: b.width * sx, height: b.height * sy), url)
      })
    }
    ctx.closePDF()

    guard let out = PDFDocument(url: outURL) else { fail("could not reopen \(outURL.path)") }
    for (i, pageLinks) in links.enumerated() {
      for (rect, url) in pageLinks {
        let link = PDFAnnotation(bounds: rect, forType: .link, withProperties: nil)
        link.url = url
        let border = PDFBorder()
        border.lineWidth = 0
        link.border = border
        out.page(at: i)?.addAnnotation(link)
      }
    }
    guard out.write(to: outURL) else { fail("could not write \(outURL.path)") }
    print("wrote \(outURL.path): \(pages.count) A4 page\(pages.count == 1 ? "" : "s"), \(links.joined().count) links")
    exit(0)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    fail("load failed: \(error)")
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    fail("load failed: \(error)")
  }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let exporter = Exporter(pageURL: pageURL, outURL: outURL)
exporter.start()
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
  fail("timed out")
}
app.run()
