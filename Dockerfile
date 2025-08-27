FROM public.ecr.aws/docker/library/python:3.13-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl dumb-init

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV MCP_TRANSPORT="streamable-http"
ENV MCP_HOST="0.0.0.0"
ENV MCP_PORT="9001"

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy uv files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-cache

# Copy environment variables
COPY env/dev.env ./.env

COPY ./src /app

# Use dumb-init to handle signals
ENTRYPOINT ["dumb-init", "--"]

EXPOSE 9001

CMD ["uv", "run", "server.py"]
