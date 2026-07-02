# Meridian example stack

A realistic backend stack for trying out Container Desktop: vector database, cache, message queue, search, object storage, and a mail catcher. Every image is arm64 native and prints useful startup logs, so the stack looks and behaves like a real project.

Launch it from Container Desktop: open the Stacks area, choose the compose launch action, and pick this `compose.yaml`. All values have defaults, so no `.env` file is required; add one next to the compose file to override any of the `${VAR:-default}` entries.

| Service     | Image                       | Host ports         | Default credentials            |
| ----------- | --------------------------- | ------------------ | ------------------------------ |
| postgres    | pgvector/pgvector:pg17      | 5432               | meridian / meridian-dev        |
| valkey      | valkey/valkey:8-alpine      | 6379               | none                           |
| rabbitmq    | rabbitmq:4-management-alpine| 5672, 15672 (UI)   | meridian / meridian-dev        |
| meilisearch | getmeili/meilisearch:latest | 7700               | key: meridian-dev-master-key   |
| minio       | minio/minio:latest          | 9000, 9001 (UI)    | meridian / meridian-dev        |
| mailpit     | axllent/mailpit:latest      | 1025 (SMTP), 8025 (UI) | none                       |

What it exercises in the app:

- **Stacks**: one project with six services, combined logs with per-service colors.
- **Containers**: a grouped list with ports, resource usage, and lifecycle actions.
- **Images**: six distinct images across Docker Hub and GHCR namespaces.
- **Volumes**: five named volumes with live usage and container cross-references.
- **Networks**: two custom networks (`backend`, `frontend`) with member lists.

The default credentials are for local development only. Do not expose these ports beyond your machine with these values.
