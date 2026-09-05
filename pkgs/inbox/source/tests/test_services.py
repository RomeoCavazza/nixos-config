import unittest

from inbox.services import classify_email, normalize_import


class ClassifierTests(unittest.TestCase):
    def test_security_message_is_high_priority(self):
        result = classify_email({"subject": "Urgent security alert", "sender_email": "alerts@example.com"})
        self.assertGreaterEqual(result["priority"], 70)
        self.assertEqual(result["category"], "Security")

    def test_import_accepts_gmail_style_payload(self):
        result = normalize_import({"emails": [{"id": "1", "from": "Ada <ada@example.com>", "subject": "Hello"}]})
        self.assertEqual(result[0]["sender_name"], "Ada")
        self.assertEqual(result[0]["sender_email"], "ada@example.com")

if __name__ == "__main__":
    unittest.main()
