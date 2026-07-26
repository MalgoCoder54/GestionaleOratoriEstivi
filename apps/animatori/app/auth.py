import base64
import json

from flask import abort, current_app, g, request


def _decode_easy_auth_principal(encoded_principal):
    if not encoded_principal:
        return None
    try:
        padding = "=" * (-len(encoded_principal) % 4)
        return json.loads(base64.b64decode(encoded_principal + padding).decode("utf-8"))
    except Exception:
        return None


def resolve_authenticated_user():
    principal = _decode_easy_auth_principal(request.headers.get("X-MS-CLIENT-PRINCIPAL"))
    if principal:
        claims = {claim.get("typ"): claim.get("val") for claim in principal.get("claims", []) if claim.get("typ")}
        name = (
            request.headers.get("X-MS-CLIENT-PRINCIPAL-NAME")
            or claims.get("name")
            or claims.get("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name")
            or claims.get("http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress")
        )
        return {"name": name, "idp": principal.get("auth_typ")}

    name = request.headers.get("X-MS-CLIENT-PRINCIPAL-NAME")
    if name:
        return {"name": name, "idp": request.headers.get("X-MS-CLIENT-PRINCIPAL-IDP")}
    return None


def init_auth(app):
    @app.before_request
    def enforce_easy_auth():
        if request.endpoint == "static":
            return
        g.auth_user = resolve_authenticated_user()
        if current_app.config.get("REQUIRE_EASY_AUTH") and not g.auth_user:
            abort(401, description="Accesso consentito solo tramite Azure Entra ID.")

    @app.context_processor
    def inject_auth_user():
        return {"auth_user": getattr(g, "auth_user", None)}
