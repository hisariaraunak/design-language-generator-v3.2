# Habitat Journey API

Python 3.11+ FastAPI service for accounts, nutrition goals, food search, meal logging, weight history, progress, and habitat rewards.

```bash
python3.11 -m venv .venv
.venv/bin/python -m pip install -e .
.venv/bin/uvicorn app.main:app --reload
```

Set `HJ_DATABASE_PATH` to choose the SQLite database file. In a production deployment, terminate TLS at the platform edge, store the database on encrypted persistent storage, and provide secrets through the deployment environment.

Run the API tests with:

```bash
.venv/bin/python -m unittest discover -s tests -v
```
