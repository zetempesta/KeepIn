from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


def to_db_color(value: int) -> int:
    if value > 0x7FFFFFFF:
        return value - 0x100000000
    return value


def to_api_color(value: int) -> int:
    return value & 0xFFFFFFFF


class NotePayload(BaseModel):
    title: str = ""
    content: str = ""
    background_color: int = Field(default=0xFFFFFFFF, alias="backgroundColor")
    labels: list[str] = Field(default_factory=list)
    is_pinned: bool = Field(default=False, alias="isPinned")

    model_config = ConfigDict(populate_by_name=True)

    @property
    def normalized_labels(self) -> list[str]:
        labels = {
            label.strip()
            for label in self.labels
            if label.strip()
        }
        return sorted(labels)


class NoteResponse(BaseModel):
    id: str
    title: str
    content: str
    background_color: int = Field(alias="backgroundColor")
    labels: list[str]
    is_pinned: bool = Field(alias="isPinned")
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")

    model_config = ConfigDict(
        populate_by_name=True,
        from_attributes=True,
    )

    @classmethod
    def from_record(cls, record: dict[str, Any]) -> "NoteResponse":
        return cls(
            id=str(record["id"]),
            title=record["title"],
            content=record["content"],
            backgroundColor=to_api_color(record["background_color"]),
            labels=list(record["labels"] or []),
            isPinned=record["is_pinned"],
            createdAt=record["created_at"],
            updatedAt=record["updated_at"],
        )


class DeleteResponse(BaseModel):
    id: UUID
    deleted: bool


class LabelPayload(BaseModel):
    name: str

    @property
    def normalized_name(self) -> str:
        return self.name.strip()


class LabelResponse(BaseModel):
    name: str


class RenameLabelPayload(BaseModel):
    new_name: str = Field(alias="newName")

    model_config = ConfigDict(populate_by_name=True)

    @property
    def normalized_new_name(self) -> str:
        return self.new_name.strip()


class DeleteLabelResponse(BaseModel):
    name: str
    deleted: bool


class LoginPayload(BaseModel):
    username: str
    password: str

    @property
    def normalized_username(self) -> str:
        return self.username.strip()


class LoginResponse(BaseModel):
    username: str
    token: str


class RegisterPayload(BaseModel):
    username: str
    password: str

    @property
    def normalized_username(self) -> str:
        return self.username.strip()
