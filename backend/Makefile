PYTHON := .venv/bin/python
PIP := $(PYTHON) -m pip

.PHONY: venv install install-dev run run-mobile test lint format typecheck migrate migration check

venv: .venv/bin/python

.venv/bin/python:
	python3 -m venv .venv

install: venv
	$(PIP) install --upgrade pip
	$(PIP) install --editable .

install-dev: venv
	$(PIP) install --upgrade pip
	$(PIP) install --editable ".[dev]"

run:
	$(PYTHON) -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

run-mobile:
	$(PYTHON) -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test:
	$(PYTHON) -m pytest

lint:
	$(PYTHON) -m ruff check .

format:
	$(PYTHON) -m ruff format .

typecheck:
	$(PYTHON) -m mypy

migrate:
	.venv/bin/alembic upgrade head

migration:
	.venv/bin/alembic revision --autogenerate -m "$(m)"

check: lint typecheck test
