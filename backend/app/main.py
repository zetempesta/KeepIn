import secrets
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from psycopg import Error as PsycopgError

from .config import settings
from .database import labels_repository, notes_repository, users_repository
from .schemas import (
    DeleteResponse,
    DeleteLabelResponse,
    LabelPayload,
    LabelResponse,
    LoginPayload,
    LoginResponse,
    RegisterPayload,
    RenameLabelPayload,
    NotePayload,
    NoteResponse,
)

app = FastAPI(
    title="KeepIn API",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

bearer_scheme = HTTPBearer(auto_error=False)
active_tokens: dict[str, str] = {}


def require_authenticated_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticacao obrigatoria.",
        )

    username = active_tokens.get(credentials.credentials)
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sessao invalida ou expirada.",
        )

    return username


@app.get("/health")
def healthcheck() -> dict[str, str]:
    return {
        "status": "ok",
        "databaseHost": settings.database_host,
    }


@app.post("/auth/login", response_model=LoginResponse)
def login(payload: LoginPayload) -> LoginResponse:
    user = users_repository.authenticate(
        payload.normalized_username,
        payload.password,
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario ou senha invalidos.",
        )

    token = secrets.token_urlsafe(32)
    active_tokens[token] = user["username"]
    return LoginResponse(username=user["username"], token=token)


@app.post("/auth/register", response_model=LoginResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterPayload) -> LoginResponse:
    if not payload.normalized_username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="O nome de usuario nao pode ficar vazio.",
        )

    if len(payload.password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A senha deve ter pelo menos 6 caracteres.",
        )

    try:
        record = users_repository.create(payload)
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while creating user: {error}",
        ) from error

    if record is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ja existe um usuario com esse nome.",
        )

    token = secrets.token_urlsafe(32)
    active_tokens[token] = record["username"]
    return LoginResponse(username=record["username"], token=token)


@app.get("/notes", response_model=list[NoteResponse])
def list_notes(current_username: str = Depends(require_authenticated_user)) -> list[NoteResponse]:
    try:
        return [
            NoteResponse.from_record(record)
            for record in notes_repository.fetch_all(current_username)
        ]
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while fetching notes: {error}",
        ) from error


@app.post("/notes", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
def create_note(
    payload: NotePayload,
    current_username: str = Depends(require_authenticated_user),
) -> NoteResponse:
    try:
        record = notes_repository.create(payload, current_username)
        return NoteResponse.from_record(record)
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while creating note: {error}",
        ) from error


@app.put("/notes/{note_id}", response_model=NoteResponse)
def update_note(
    note_id: UUID,
    payload: NotePayload,
    current_username: str = Depends(require_authenticated_user),
) -> NoteResponse:
    try:
        record = notes_repository.update(note_id, payload, current_username)
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while updating note: {error}",
        ) from error

    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found.",
        )

    return NoteResponse.from_record(record)


@app.delete("/notes/{note_id}", response_model=DeleteResponse)
def delete_note(
    note_id: UUID,
    current_username: str = Depends(require_authenticated_user),
) -> DeleteResponse:
    try:
        deleted = notes_repository.delete(note_id, current_username)
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while deleting note: {error}",
        ) from error

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found.",
        )

    return DeleteResponse(id=note_id, deleted=True)


@app.get("/labels", response_model=list[LabelResponse])
def list_labels(current_username: str = Depends(require_authenticated_user)) -> list[LabelResponse]:
    try:
        return [
            LabelResponse(name=record["name"])
            for record in labels_repository.fetch_all(current_username)
        ]
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while fetching labels: {error}",
        ) from error


@app.post("/labels", response_model=LabelResponse, status_code=status.HTTP_201_CREATED)
def create_label(
    payload: LabelPayload,
    current_username: str = Depends(require_authenticated_user),
) -> LabelResponse:
    normalized = payload.normalized_name
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Label name cannot be empty.",
        )

    try:
        record = labels_repository.create(payload, current_username)
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while creating label: {error}",
        ) from error

    if record is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Label name cannot be empty.",
        )

    return LabelResponse(name=record["name"])


@app.put("/labels/{label_name}", response_model=LabelResponse)
def rename_label(
    label_name: str,
    payload: RenameLabelPayload,
    current_username: str = Depends(require_authenticated_user),
) -> LabelResponse:
    normalized_current_name = label_name.strip()
    normalized_new_name = payload.normalized_new_name
    if not normalized_new_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New label name cannot be empty.",
        )

    if not labels_repository.exists(normalized_current_name, current_username):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Label not found.",
        )

    if (
        normalized_current_name != normalized_new_name
        and labels_repository.exists(normalized_new_name, current_username)
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ja existe uma label com esse nome.",
        )

    try:
        record = labels_repository.rename(
            normalized_current_name,
            normalized_new_name,
            current_username,
        )
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while renaming label: {error}",
        ) from error

    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Label not found.",
        )

    return LabelResponse(name=record["name"])


@app.delete("/labels/{label_name}", response_model=DeleteLabelResponse)
def delete_label(
    label_name: str,
    current_username: str = Depends(require_authenticated_user),
) -> DeleteLabelResponse:
    try:
        deleted = labels_repository.delete(label_name, current_username)
    except PsycopgError as error:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while deleting label: {error}",
        ) from error

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Label not found.",
        )

    return DeleteLabelResponse(name=label_name, deleted=True)
