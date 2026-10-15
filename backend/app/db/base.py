from datetime import UTC, datetime

from sqlalchemy import DateTime, MetaData
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


class SoftDeleteMixin:
    """Adds reversible deletion state to mutable operational records."""

    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)

    def soft_delete(self, *, deleted_at: datetime | None = None) -> None:
        self.deleted_at = deleted_at or datetime.now(UTC)

    def restore(self) -> None:
        self.deleted_at = None
