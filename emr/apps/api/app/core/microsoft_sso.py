"""Microsoft JWKS token validation utilities."""
from __future__ import annotations
import time
from typing import Any
import httpx
from jose import jwt, JWTError

_jwks_cache: dict[str, Any] = {}  # {url: {keys: [...], fetched_at: float}}
_CACHE_TTL = 3600  # refresh JWKS every hour


async def _get_jwks(tenant_id: str) -> list[dict]:
    url = f"https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys"
    cached = _jwks_cache.get(url)
    if cached and time.time() - cached["fetched_at"] < _CACHE_TTL:
        return cached["keys"]
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        keys = resp.json()["keys"]
    _jwks_cache[url] = {"keys": keys, "fetched_at": time.time()}
    return keys


async def validate_microsoft_id_token(id_token: str, client_id: str, tenant_id: str) -> dict:
    """
    Validate a Microsoft ID token and return the claims dict.
    Raises ValueError on any validation failure.

    tenant_id can be a specific tenant UUID, "common", or "organizations".
    For "common" / "organizations", we use the issuer embedded in the token
    to fetch the right JWKS.
    """
    # Decode header without verification to get kid + issuer for JWKS selection
    try:
        unverified = jwt.get_unverified_claims(id_token)
        unverified_header = jwt.get_unverified_header(id_token)
    except JWTError as exc:
        raise ValueError(f"Malformed token: {exc}") from exc

    # For multi-tenant, the actual issuer comes from the token itself
    issuer = unverified.get("iss", "")
    # Extract tenant from issuer (https://login.microsoftonline.com/{tid}/v2.0)
    jwks_tenant = tenant_id
    if tenant_id in ("common", "organizations", "consumers"):
        parts = issuer.split("/")
        # issuer format: https://login.microsoftonline.com/{tid}/v2.0
        try:
            jwks_tenant = parts[3]
        except IndexError:
            raise ValueError("Cannot determine tenant from issuer")

    keys = await _get_jwks(jwks_tenant)
    kid = unverified_header.get("kid")
    matching = [k for k in keys if k.get("kid") == kid]
    if not matching:
        # Key rolled — bust cache and retry once
        _jwks_cache.pop(f"https://login.microsoftonline.com/{jwks_tenant}/discovery/v2.0/keys", None)
        keys = await _get_jwks(jwks_tenant)
        matching = [k for k in keys if k.get("kid") == kid]
    if not matching:
        raise ValueError(f"No JWKS key found for kid={kid}")

    try:
        claims = jwt.decode(
            id_token,
            {"keys": matching},
            algorithms=["RS256"],
            audience=client_id,
        )
    except JWTError as exc:
        raise ValueError(f"Token validation failed: {exc}") from exc

    return claims
