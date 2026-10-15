from importlib import import_module
from importlib.metadata import version


def test_project_package_is_installed() -> None:
    assert version("responda-backend") == "0.1.0"


def test_foundation_dependencies_are_importable() -> None:
    for package in ("alembic", "fastapi", "psycopg", "pydantic_settings", "sqlalchemy", "uvicorn"):
        assert import_module(package) is not None
