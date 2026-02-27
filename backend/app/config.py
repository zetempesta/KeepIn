from urllib.parse import urlparse

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str | None = None
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "keepin"
    db_user: str = "postgres"
    db_password: str = "postgres"
    api_host: str = "127.0.0.1"
    api_port: int = 8000

    model_config = SettingsConfigDict(
        env_prefix="KEEPIN_",
        env_file=".env",
        extra="ignore",
    )

    @property
    def database_dsn(self) -> str:
        if self.database_url:
            return self.database_url

        return (
            f"host={self.db_host} "
            f"port={self.db_port} "
            f"dbname={self.db_name} "
            f"user={self.db_user} "
            f"password={self.db_password}"
        )

    @property
    def database_host(self) -> str:
        if not self.database_url:
            return self.db_host

        parsed = urlparse(self.database_url)
        return parsed.hostname or "unknown"


settings = Settings()
