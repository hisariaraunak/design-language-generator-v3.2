from datetime import datetime
from pydantic import BaseModel, EmailStr, Field

class RegisterRequest(BaseModel):
    email: EmailStr; password: str = Field(min_length=10, max_length=128); display_name: str = Field(min_length=1, max_length=60)
class LoginRequest(BaseModel): email: EmailStr; password: str
class SessionResponse(BaseModel): token: str; user_id: str; expires_at: str
class Goals(BaseModel):
    calories: int = Field(ge=800, le=10000); protein: float = Field(ge=0, le=1000); carbs: float = Field(ge=0, le=1500); fat: float = Field(ge=0, le=1000); fiber: float = Field(ge=0, le=300)
class FoodResponse(BaseModel):
    id: str; name: str; detail: str; emoji: str; calories: int; protein: float; carbs: float; fat: float; fiber: float; is_verified: bool
class FoodCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100); detail: str = Field(min_length=1, max_length=100); emoji: str = Field(min_length=1, max_length=8)
    calories: int = Field(ge=0, le=10000); protein: float = Field(ge=0, le=1000); carbs: float = Field(ge=0, le=1500); fat: float = Field(ge=0, le=1000); fiber: float = Field(ge=0, le=300)
class EntryCreate(BaseModel): food_id: str; meal: str; servings: float = Field(gt=0, le=20); logged_at: datetime
class EntryResponse(BaseModel): id: str; food: FoodResponse; meal: str; servings: float; logged_at: str
class WeightCreate(BaseModel): kilograms: float = Field(ge=20, le=500); recorded_at: datetime
