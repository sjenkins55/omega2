"""
Security middleware:
  - Adds OWASP-recommended HTTP security headers to every response.
  - Writes HIPAA audit events for mutating requests that carry a valid staff JWT.
"""
from __future__ import annotations
import logging
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)

_SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "X-XSS-Protection": "1; mode=block",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "geolocation=(), microphone=(), camera=()",
    # HSTS — only meaningful over TLS; harmless over HTTP
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
}

# HTTP methods that modify data → logged to AuditEvent
_WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        for k, v in _SECURITY_HEADERS.items():
            response.headers[k] = v
        return response


class AuditLogMiddleware(BaseHTTPMiddleware):
    """
    Logs write operations that carry a valid staff JWT.
    Reads the JWT sub claim without re-validating against DB (middleware
    can't hold an async DB session easily); full validation happens in route deps.
    PHI-containing request bodies are NOT logged — only method, path, status.
    """
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)

        if request.method not in _WRITE_METHODS:
            return response

        # Decode JWT lazily — skip if missing or malformed (unauthenticated calls)
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return response

        token = auth.split(" ", 1)[1]
        try:
            from jose import jwt as jose_jwt
            from app.core.config import get_settings
            settings = get_settings()
            payload = jose_jwt.decode(token, settings.secret_key, algorithms=["HS256"])
            if payload.get("type") != "staff":
                return response
            user_id = payload.get("sub")
        except Exception:
            return response

        # Derive audit fields from path
        path_parts = request.url.path.strip("/").split("/")
        # e.g. ["api", "v1", "patients", "<uuid>"] → resource_type=patient
        resource_type = path_parts[2] if len(path_parts) > 2 else "unknown"
        resource_id = path_parts[3] if len(path_parts) > 3 else None

        action_map = {"POST": "create", "PUT": "update", "PATCH": "update", "DELETE": "delete"}
        action = action_map.get(request.method, "write")

        ip = request.headers.get("X-Forwarded-For", request.client.host if request.client else None)

        # Write to DB asynchronously — fire-and-forget so we don't slow requests
        try:
            from app.db.base import AsyncSessionLocal
            from app.models.audit_event import AuditEvent
            async with AsyncSessionLocal() as db:
                event = AuditEvent(
                    user_id=user_id,
                    action=action,
                    resource_type=resource_type,
                    resource_id=resource_id,
                    ip_address=ip,
                    user_agent=request.headers.get("User-Agent"),
                    extra={"path": request.url.path, "status": response.status_code},
                )
                db.add(event)
                await db.commit()
        except Exception as exc:
            logger.warning("Audit log write failed: %s", exc)

        return response
