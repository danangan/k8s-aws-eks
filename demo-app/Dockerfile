FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.12.13 /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project --no-dev

COPY app/ ./app/
RUN uv sync --locked --no-dev

RUN useradd --create-home appuser && chown -R appuser /app
USER appuser

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
