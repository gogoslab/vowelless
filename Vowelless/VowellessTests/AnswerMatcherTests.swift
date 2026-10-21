import Testing
@testable import Vowelless

/// Speech recognizers write numbers and names in their own way; these should still count.
struct AnswerMatcherTests {
    @Test(arguments: [
        ("twenty one pilots", "Twenty One Pilots"),
        ("21 pilots", "Twenty One Pilots"),
        ("maroon five", "Maroon 5"),
        ("blink 182", "Blink-182"),
        ("oceans eleven", "Ocean's Eleven"),
        ("catch twenty two", "Catch-22"),
        ("the jackson five", "The Jackson 5"),
        ("guns and roses", "Guns N' Roses"),
        ("Spider Man", "Spider-Man"),
        ("Bohemian Rhapsody", "Bohemian Rhapsody"),
    ])
    func spokenAnswersMatch(said: String, answer: String) {
        #expect(AnswerMatcher.matches(said, answer))
    }

    @Test func wrongAnswersDoNotMatch() {
        #expect(!AnswerMatcher.matches("maroon six", "Maroon 5"))
        #expect(!AnswerMatcher.matches("", "Maroon 5"))
        #expect(!AnswerMatcher.matches("bohemian", "Bohemian Rhapsody"))
    }
}
