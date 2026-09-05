import unittest

from inbox.assistant import DemoAssistant


EMAIL = {
    "sender_name": "Maya Chen",
    "subject": "Action required: final design review today",
    "snippet": "Could you approve the dashboard before our 3 PM call?",
    "body": "The dashboard is ready. Three decisions still need your input.",
    "priority": 70,
}


class DemoAssistantTests(unittest.TestCase):
    def setUp(self):
        self.assistant = DemoAssistant()

    def test_priority_explains_the_action(self):
        result = self.assistant.analyze_priority(EMAIL)
        self.assertGreaterEqual(result.score, 80)
        self.assertIn("Review", result.action)

    def test_summary_uses_message_content(self):
        self.assertEqual(
            self.assistant.summarize(EMAIL),
            "The dashboard is ready. Three decisions still need your input.",
        )

    def test_reply_is_addressed_and_signed(self):
        reply = self.assistant.suggest_reply(EMAIL, "Demo User")
        self.assertTrue(reply.startswith("Hi Maya,"))
        self.assertTrue(reply.endswith("Demo User"))


if __name__ == "__main__":
    unittest.main()
