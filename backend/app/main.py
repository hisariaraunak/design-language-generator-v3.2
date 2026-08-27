from __future__ import annotations

import json
import os
import sqlite3
import uuid
from datetime import date, datetime, timezone
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Query, status

from .auth import hash_password, new_session, token_hash, verify_password
from .database import Database
from .schemas import EntryCreate, EntryResponse, FoodCreate, FoodResponse, Goals, LoginRequest, RegisterRequest, SessionResponse, WeightCreate

DB_PATH = os.environ.get("HJ_DATABASE_PATH", str(Path(__file__).resolve().parents[1] / "habitat_journey.db"))
db = Database(DB_PATH)
app = FastAPI(title="Habitat Journey API", version="0.9.0", docs_url="/docs")


def row_food(row) -> dict:
    return {"id": row["id"], "name": row["name"], "detail": row["detail"], "emoji": row["emoji"], "calories": row["calories"], "protein": row["protein"], "carbs": row["carbs"], "fat": row["fat"], "fiber": row["fiber"], "is_verified": bool(row["is_verified"])}


def current_user(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "): raise HTTPException(status_code=401, detail="Authentication required")
    digest = token_hash(authorization[7:])
    with db.connect() as connection:
        row = connection.execute("SELECT user_id FROM sessions WHERE token_hash=? AND expires_at > ?", (digest, datetime.now(timezone.utc).isoformat())).fetchone()
    if not row: raise HTTPException(status_code=401, detail="Session expired")
    return row["user_id"]


@app.get("/health")
def health(): return {"status": "ok", "version": app.version}


@app.post("/v1/auth/register", response_model=SessionResponse, status_code=201)
def register(body: RegisterRequest):
    user_id = str(uuid.uuid4()); token, digest, expires = new_session()
    try:
        with db.transaction() as connection:
            connection.execute("INSERT INTO users(id,email,password_hash,display_name) VALUES(?,?,?,?)", (user_id, body.email.lower(), hash_password(body.password), body.display_name.strip()))
            connection.execute("INSERT INTO goals(user_id,calories,protein,carbs,fat,fiber) VALUES(?,?,?,?,?,?)", (user_id, 2000, 120, 250, 70, 30))
            connection.execute("INSERT INTO habitat_state(user_id,xp,level) VALUES(?,?,?)", (user_id, 0, 1))
            connection.execute("INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,?)", (digest, user_id, expires))
    except sqlite3.IntegrityError: raise HTTPException(status_code=409, detail="An account already exists")
    return SessionResponse(token=token, user_id=user_id, expires_at=expires)


@app.post("/v1/auth/login", response_model=SessionResponse)
def login(body: LoginRequest):
    with db.connect() as connection: user = connection.execute("SELECT id,password_hash FROM users WHERE email=? COLLATE NOCASE", (body.email,)).fetchone()
    if not user or not verify_password(body.password, user["password_hash"]): raise HTTPException(status_code=401, detail="Invalid email or password")
    token, digest, expires = new_session()
    with db.transaction() as connection: connection.execute("INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,?)", (digest, user["id"], expires))
    return SessionResponse(token=token, user_id=user["id"], expires_at=expires)


@app.post("/v1/auth/logout", status_code=204)
def logout(authorization: str | None = Header(default=None), user_id: str = Depends(current_user)):
    digest = token_hash(authorization[7:])
    with db.transaction() as connection:
        connection.execute("DELETE FROM sessions WHERE token_hash=? AND user_id=?", (digest, user_id))


@app.get("/v1/foods", response_model=list[FoodResponse])
def foods(q: str = Query(default="", max_length=100), user_id: str = Depends(current_user)):
    with db.connect() as connection:
        rows = connection.execute("SELECT * FROM foods WHERE (owner_user_id IS NULL OR owner_user_id=?) AND name LIKE ? ORDER BY is_verified DESC,name LIMIT 100", (user_id, f"%{q}%")).fetchall()
    return [row_food(row) for row in rows]


@app.post("/v1/foods", response_model=FoodResponse, status_code=201)
def create_food(body: FoodCreate, user_id: str = Depends(current_user)):
    food_id = str(uuid.uuid4())
    with db.transaction() as connection:
        connection.execute("""INSERT INTO foods(id,owner_user_id,name,detail,emoji,calories,protein,carbs,fat,fiber,is_verified)
          VALUES(?,?,?,?,?,?,?,?,?,?,0)""", (food_id, user_id, body.name.strip(), body.detail.strip(), body.emoji, body.calories, body.protein, body.carbs, body.fat, body.fiber))
        row = connection.execute("SELECT * FROM foods WHERE id=?", (food_id,)).fetchone()
    return row_food(row)


@app.get("/v1/goals", response_model=Goals)
def get_goals(user_id: str = Depends(current_user)):
    with db.connect() as connection: row = connection.execute("SELECT calories,protein,carbs,fat,fiber FROM goals WHERE user_id=?", (user_id,)).fetchone()
    return dict(row)


@app.put("/v1/goals", response_model=Goals)
def put_goals(body: Goals, user_id: str = Depends(current_user)):
    with db.transaction() as connection: connection.execute("UPDATE goals SET calories=?,protein=?,carbs=?,fat=?,fiber=?,updated_at=CURRENT_TIMESTAMP WHERE user_id=?", (*body.model_dump().values(), user_id))
    return body


@app.post("/v1/entries", response_model=EntryResponse, status_code=201)
def create_entry(body: EntryCreate, user_id: str = Depends(current_user)):
    if body.meal not in {"Breakfast","Lunch","Dinner","Snack"}: raise HTTPException(status_code=422, detail="Invalid meal")
    entry_id = str(uuid.uuid4())
    with db.transaction() as connection:
        food = connection.execute("SELECT * FROM foods WHERE id=? AND (owner_user_id IS NULL OR owner_user_id=?)", (body.food_id, user_id)).fetchone()
        if not food: raise HTTPException(status_code=404, detail="Food not found")
        connection.execute("INSERT INTO food_entries(id,user_id,food_id,meal,servings,logged_at) VALUES(?,?,?,?,?,?)", (entry_id, user_id, body.food_id, body.meal, body.servings, body.logged_at.isoformat()))
        connection.execute("UPDATE habitat_state SET xp=xp+10,level=MAX(level,CAST((xp+10)/250 AS INTEGER)+1),updated_at=CURRENT_TIMESTAMP WHERE user_id=?", (user_id,))
    return {"id": entry_id, "food": row_food(food), "meal": body.meal, "servings": body.servings, "logged_at": body.logged_at.isoformat()}


@app.get("/v1/entries", response_model=list[EntryResponse])
def list_entries(day: date, user_id: str = Depends(current_user)):
    with db.connect() as connection:
        rows = connection.execute("""SELECT e.id entry_id,e.meal,e.servings,e.logged_at,f.* FROM food_entries e JOIN foods f ON f.id=e.food_id
          WHERE e.user_id=? AND substr(e.logged_at,1,10)=? ORDER BY e.logged_at""", (user_id, day.isoformat())).fetchall()
    return [{"id": row["entry_id"], "food": row_food(row), "meal": row["meal"], "servings": row["servings"], "logged_at": row["logged_at"]} for row in rows]


@app.delete("/v1/entries/{entry_id}", status_code=204)
def delete_entry(entry_id: str, user_id: str = Depends(current_user)):
    with db.transaction() as connection:
        result = connection.execute("DELETE FROM food_entries WHERE id=? AND user_id=?", (entry_id, user_id))
        if result.rowcount == 0: raise HTTPException(status_code=404, detail="Entry not found")


@app.get("/v1/dashboard")
def dashboard(day: date, user_id: str = Depends(current_user)):
    with db.connect() as connection:
        goals = dict(connection.execute("SELECT calories,protein,carbs,fat,fiber FROM goals WHERE user_id=?", (user_id,)).fetchone())
        totals = connection.execute("""SELECT COALESCE(SUM(f.calories*e.servings),0) calories,COALESCE(SUM(f.protein*e.servings),0) protein,
          COALESCE(SUM(f.carbs*e.servings),0) carbs,COALESCE(SUM(f.fat*e.servings),0) fat,COALESCE(SUM(f.fiber*e.servings),0) fiber
          FROM food_entries e JOIN foods f ON f.id=e.food_id WHERE e.user_id=? AND substr(e.logged_at,1,10)=?""", (user_id, day.isoformat())).fetchone()
        habitat = connection.execute("SELECT xp,level,unlocked_friends FROM habitat_state WHERE user_id=?", (user_id,)).fetchone()
    return {"date": day, "goals": goals, "consumed": dict(totals), "remaining_calories": max(0, goals["calories"]-round(totals["calories"])), "habitat": {"xp": habitat["xp"], "level": habitat["level"], "unlocked_friends": json.loads(habitat["unlocked_friends"])}}


@app.post("/v1/weights", status_code=201)
def create_weight(body: WeightCreate, user_id: str = Depends(current_user)):
    record_id = str(uuid.uuid4())
    with db.transaction() as connection: connection.execute("INSERT INTO weights(id,user_id,kilograms,recorded_at) VALUES(?,?,?,?)", (record_id, user_id, body.kilograms, body.recorded_at.isoformat()))
    return {"id": record_id, **body.model_dump(mode="json")}


@app.get("/v1/weights")
def list_weights(limit: int = Query(default=90, ge=1, le=365), user_id: str = Depends(current_user)):
    with db.connect() as connection:
        rows = connection.execute("SELECT id,kilograms,recorded_at FROM weights WHERE user_id=? ORDER BY recorded_at DESC LIMIT ?", (user_id, limit)).fetchall()
    return [dict(row) for row in rows]


@app.get("/v1/progress")
def progress(days: int = Query(default=7, ge=1, le=90), user_id: str = Depends(current_user)):
    with db.connect() as connection:
        rows = connection.execute("""SELECT substr(e.logged_at,1,10) day,ROUND(SUM(f.calories*e.servings)) calories
          FROM food_entries e JOIN foods f ON f.id=e.food_id WHERE e.user_id=?
          GROUP BY substr(e.logged_at,1,10) ORDER BY day DESC LIMIT ?""", (user_id, days)).fetchall()
    return list(reversed([dict(row) for row in rows]))


@app.post("/v1/habitat/unlock/{friend_id}")
def unlock_friend(friend_id: str, user_id: str = Depends(current_user)):
    requirements = {"reed": 250, "crabby": 500, "shelly": 630}
    if friend_id not in requirements: raise HTTPException(status_code=404, detail="Unknown friend")
    with db.transaction() as connection:
        row = connection.execute("SELECT xp,unlocked_friends FROM habitat_state WHERE user_id=?", (user_id,)).fetchone(); unlocked = json.loads(row["unlocked_friends"])
        if row["xp"] < requirements[friend_id]: raise HTTPException(status_code=409, detail="More Habitat XP is required")
        if friend_id not in unlocked: unlocked.append(friend_id); connection.execute("UPDATE habitat_state SET unlocked_friends=?,updated_at=CURRENT_TIMESTAMP WHERE user_id=?", (json.dumps(unlocked), user_id))
    return {"friend_id": friend_id, "unlocked": True}
