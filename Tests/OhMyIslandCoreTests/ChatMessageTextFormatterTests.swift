import XCTest
@testable import OhMyIslandCore

final class ChatMessageTextFormatterTests: XCTestCase {
    func testUserMessagesStayLiteralEvenWhenTheyContainMarkdownSyntax() {
        let rendered = ChatMessageTextFormatter.displayText(
            for: ChatMessage(isUser: true, text: "~/demo/path ~~draft~~ `--flag`")
        )

        XCTAssertEqual(String(rendered.characters), "~/demo/path ~~draft~~ `--flag`")
        XCTAssertTrue(rendered.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }

    func testAssistantMessagesStillRenderInlineMarkdown() {
        let rendered = ChatMessageTextFormatter.displayText(
            for: ChatMessage(isUser: false, text: "**Done**")
        )

        XCTAssertEqual(String(rendered.characters), "Done")
        XCTAssertTrue(rendered.runs.contains { $0.inlinePresentationIntent != nil })
    }
}
