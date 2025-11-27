import NIOCore
import NIOHTTP1

/// Handles HTTP 100 Continue expectations by sending an immediate response
/// when the Expect: 100-continue header is present
final class HTTP100ContinueHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)

        switch reqPart {
        case .head(let head):
            // Check for Expect: 100-continue header
            if head.headers.contains(name: "Expect") {
                let expectValues = head.headers["Expect"]
                if expectValues.contains(where: { $0.lowercased().contains("100-continue") }) {
                    // Send 100 Continue response immediately
                    let continueHead = HTTPResponseHead(
                        version: head.version,
                        status: .continue
                    )

                    // Write the 100 Continue response
                    context.write(self.wrapOutboundOut(.head(continueHead)), promise: nil)
                    context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
                    context.flush()
                }
            }

            // Always forward the request head to the next handler
            context.fireChannelRead(data)

        case .body, .end:
            // Forward body and end parts as-is
            context.fireChannelRead(data)
        }
    }
}
