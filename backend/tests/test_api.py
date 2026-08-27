import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from fastapi.testclient import TestClient

from app.database import Database
from app import main


class HabitatJourneyAPITests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        main.db = Database(Path(self.tempdir.name) / "test.db")
        self.client = TestClient(main.app)
        response = self.client.post("/v1/auth/register", json={
            "email": "ollie@example.com", "password": "riverbank-strong", "display_name": "Ollie"
        })
        self.assertEqual(response.status_code, 201)
        self.token = response.json()["token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}

    def tearDown(self):
        self.tempdir.cleanup()

    def test_full_tracking_flow(self):
        foods = self.client.get("/v1/foods?q=yogurt", headers=self.headers)
        self.assertEqual(foods.status_code, 200)
        self.assertEqual(foods.json()[0]["id"], "greek-yogurt")

        logged_at = datetime.now(timezone.utc).isoformat()
        entry = self.client.post("/v1/entries", headers=self.headers, json={
            "food_id": "greek-yogurt", "meal": "Breakfast", "servings": 1.5, "logged_at": logged_at
        })
        self.assertEqual(entry.status_code, 201)
        day = logged_at[:10]
        dashboard = self.client.get(f"/v1/dashboard?day={day}", headers=self.headers)
        self.assertEqual(dashboard.status_code, 200)
        self.assertEqual(dashboard.json()["consumed"]["calories"], 150)
        self.assertEqual(dashboard.json()["habitat"]["xp"], 10)

        deleted = self.client.delete(f"/v1/entries/{entry.json()['id']}", headers=self.headers)
        self.assertEqual(deleted.status_code, 204)
        self.assertEqual(self.client.get(f"/v1/entries?day={day}", headers=self.headers).json(), [])

    def test_account_isolation_custom_food_and_logout(self):
        custom = self.client.post("/v1/foods", headers=self.headers, json={
            "name": "Forest bowl", "detail": "1 bowl", "emoji": "🥗", "calories": 410,
            "protein": 18, "carbs": 52, "fat": 14, "fiber": 9
        })
        self.assertEqual(custom.status_code, 201)
        self.assertFalse(custom.json()["is_verified"])
        duplicate = self.client.post("/v1/auth/register", json={
            "email": "OLLIE@example.com", "password": "another-strong-one", "display_name": "Other"
        })
        self.assertEqual(duplicate.status_code, 409)
        self.assertEqual(self.client.post("/v1/auth/logout", headers=self.headers).status_code, 204)
        self.assertEqual(self.client.get("/v1/foods", headers=self.headers).status_code, 401)

    def test_validation_and_habitat_gate(self):
        invalid = self.client.post("/v1/entries", headers=self.headers, json={
            "food_id": "banana", "meal": "Brunch", "servings": 1, "logged_at": datetime.now(timezone.utc).isoformat()
        })
        self.assertEqual(invalid.status_code, 422)
        locked = self.client.post("/v1/habitat/unlock/shelly", headers=self.headers)
        self.assertEqual(locked.status_code, 409)
        unauthenticated = self.client.get("/v1/goals")
        self.assertEqual(unauthenticated.status_code, 401)


if __name__ == "__main__":
    unittest.main()
