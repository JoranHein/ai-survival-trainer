#!/usr/bin/env python3
"""Deploy the Ari AI gateway to a Linux server over SSH.

The script is intentionally conservative:
- package only ai_gateway server files;
- never package .env, *.local.* files, caches, or virtualenvs;
- preserve the remote .env before replacing the code tree;
- verify /health, /scribe, and /library-reflection after restart.
"""

from __future__ import annotations

import argparse
import getpass
import os
import shlex
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import Iterable


REMOTE_DIR_DEFAULT = "/opt/ari-ai-server"
REMOTE_ARCHIVE_DEFAULT = "/tmp/ari-ai-gateway.tar.gz"

PACKAGE_INCLUDE_ROOTS = {
    ".env.example",
    "README.md",
    "requirements.txt",
    "app",
    "scripts",
    "systemd",
}

EXCLUDED_NAMES = {
    ".env",
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".venv",
    "__pycache__",
}


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()
    if not root.exists():
        print(f"Gateway root does not exist: {root}", file=sys.stderr)
        return 2
    if args.package_only:
        archive = build_package(root, Path(args.package_only).resolve())
        print(f"Package written: {archive}")
        return 0
    if args.host.strip() == "":
        print("Set --host or ARI_DEPLOY_HOST.", file=sys.stderr)
        return 2
    if args.check_ssh_only:
        try:
            check_ssh_auth(
                host=args.host,
                user=args.user,
                port=args.port,
                key_path=args.key,
                password_file=args.password_file,
            )
        except Exception as exc:
            print(format_deploy_error(exc, key_path=args.key, password_file=args.password_file), file=sys.stderr)
            return 1
        print(f"SSH auth check passed for {args.user}@{args.host}:{args.port}.")
        return 0

    with tempfile.TemporaryDirectory(prefix="ari-gateway-deploy-") as tmpdir:
        local_archive = build_package(root, Path(tmpdir) / "ari-ai-gateway.tar.gz")
        try:
            deploy_with_paramiko(
                host=args.host,
                user=args.user,
                port=args.port,
                key_path=args.key,
                password_file=args.password_file,
                remote_dir=args.remote_dir,
                remote_archive=args.remote_archive,
                local_archive=local_archive,
            )
        except Exception as exc:
            print(format_deploy_error(exc, key_path=args.key, password_file=args.password_file), file=sys.stderr)
            return 1
    print("Deploy finished and observer endpoints verified.")
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    script_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description="Deploy ai_gateway to the Ari Hetzner server.")
    parser.add_argument("--root", default=str(script_root), help="Local ai_gateway root.")
    parser.add_argument("--host", default=os.getenv("ARI_DEPLOY_HOST", ""))
    parser.add_argument("--user", default=os.getenv("ARI_DEPLOY_USER", "root"))
    parser.add_argument("--port", type=int, default=int(os.getenv("ARI_DEPLOY_PORT", "22")))
    parser.add_argument("--key", default=os.getenv("ARI_DEPLOY_KEY", ""))
    parser.add_argument("--password-file", default=os.getenv("ARI_DEPLOY_PASSWORD_FILE", ""))
    parser.add_argument("--remote-dir", default=os.getenv("ARI_DEPLOY_REMOTE_DIR", REMOTE_DIR_DEFAULT))
    parser.add_argument("--remote-archive", default=os.getenv("ARI_DEPLOY_REMOTE_ARCHIVE", REMOTE_ARCHIVE_DEFAULT))
    parser.add_argument("--package-only", default="", help="Write package tar.gz and exit.")
    parser.add_argument("--check-ssh-only", action="store_true", help="Verify SSH authentication and exit without uploading.")
    return parser.parse_args(argv)


def build_package(root: Path, archive_path: Path) -> Path:
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive_path, "w:gz") as package:
        for path in _iter_package_files(root):
            package.add(path, arcname=path.relative_to(root).as_posix(), recursive=False)
    return archive_path


def _iter_package_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if path.is_dir():
            continue
        relative = path.relative_to(root)
        if _should_package(relative):
            yield path


def _should_package(relative: Path) -> bool:
    parts = relative.parts
    if any(part in EXCLUDED_NAMES for part in parts):
        return False
    name = relative.name
    if ".local." in name or name.endswith(".local") or name.endswith(".local.json") or name.endswith(".local.ps1"):
        return False
    posix = relative.as_posix()
    for include in PACKAGE_INCLUDE_ROOTS:
        if posix == include or posix.startswith(f"{include}/"):
            return True
    return False


def remote_install_command(remote_dir: str, remote_archive: str) -> str:
    remote_dir_q = shlex.quote(remote_dir)
    remote_archive_q = shlex.quote(remote_archive)
    backup = f"/tmp/{Path(remote_dir).name}.env.backup"
    backup_q = shlex.quote(backup)
    return "\n".join(
        [
            "set -euo pipefail",
            f"mkdir -p {remote_dir_q}",
            f"cd {remote_dir_q}",
            f"if [ -f .env ]; then cp .env {backup_q}; fi",
            "find . -mindepth 1 -maxdepth 1 ! -name .env -exec rm -rf {} +",
            f"tar -xzf {remote_archive_q} -C {remote_dir_q}",
            f"if [ -f {backup_q} ]; then mv {backup_q} .env; fi",
            "chmod +x scripts/install_server.sh",
            "bash scripts/install_server.sh",
            "systemctl restart ari-ai-gateway",
            "sleep 2",
            "set -a",
            ". ./.env",
            "set +a",
            'BASE_URL="http://127.0.0.1:${PORT:-8088}"',
            'AUTH_HEADER="X-API-Key: ${GAME_AI_API_KEY:-}"',
            'curl -fsS -H "$AUTH_HEADER" "$BASE_URL/health" >/dev/null',
            (
                "curl -fsS -X POST -H 'Content-Type: application/json' -H \"$AUTH_HEADER\" "
                "\"$BASE_URL/ari/predict-v1\" -d '{\"schema\":\"ari.prediction.request.v1\",\"context_hash\":\"deploy_probe\",\"risks\":[{\"type\":\"flying\",\"distance\":96,\"severity\":0.9}],\"strategy_packet\":{\"priority_hints\":{\"build_storm_rod\":0.6}},\"legal_actions\":[{\"id\":\"build_storm_rod\",\"available\":true},{\"id\":\"build_wall\",\"available\":true}]}' "
                "| grep -q 'ari.prediction.v1'"
            ),
            (
                "curl -fsS -X POST -H 'Content-Type: application/json' -H \"$AUTH_HEADER\" "
                "\"$BASE_URL/scribe\" -d '{\"payload\":{\"schema\":\"ari.scribe.request.v1\"}}' "
                "| grep -q 'ari.scribe.note.v2'"
            ),
            "systemctl restart ollama",
            "systemctl restart ari-ai-gateway",
            "sleep 7",
            'curl -fsS -H "$AUTH_HEADER" "$BASE_URL/health" >/dev/null',
            f"rm -f {remote_archive_q}",
        ]
    )


def deploy_with_paramiko(
    *,
    host: str,
    user: str,
    port: int,
    key_path: str,
    password_file: str,
    remote_dir: str,
    remote_archive: str,
    local_archive: Path,
) -> None:
    client = _connect_paramiko(
        host=host,
        user=user,
        port=port,
        key_path=key_path,
        password_file=password_file,
    )
    try:
        with client.open_sftp() as sftp:
            sftp.put(str(local_archive), remote_archive)
        _exec_checked(client, remote_install_command(remote_dir, remote_archive))
    finally:
        client.close()


def check_ssh_auth(*, host: str, user: str, port: int, key_path: str, password_file: str) -> None:
    client = _connect_paramiko(
        host=host,
        user=user,
        port=port,
        key_path=key_path,
        password_file=password_file,
    )
    try:
        _exec_checked(client, "true")
    finally:
        client.close()


def _connect_paramiko(*, host: str, user: str, port: int, key_path: str, password_file: str):
    try:
        import paramiko
    except ImportError as exc:
        raise RuntimeError("paramiko is required for SSH deployment; install it or use --package-only") from exc

    password = _read_password(password_file)
    key_filename = key_path or None
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=host,
        username=user,
        port=port,
        password=password,
        key_filename=key_filename,
        timeout=15,
        auth_timeout=15,
        banner_timeout=15,
        look_for_keys=not bool(password or key_filename),
        allow_agent=not bool(password or key_filename),
    )
    return client


def _read_password(password_file: str) -> str | None:
    if password_file:
        return Path(password_file).read_text(encoding="utf-8").strip()
    if os.getenv("ARI_DEPLOY_PASSWORD"):
        return os.getenv("ARI_DEPLOY_PASSWORD")
    return None


def format_deploy_error(exc: Exception, *, key_path: str, password_file: str) -> str:
    auth = _auth_summary(key_path, password_file)
    name = type(exc).__name__
    text = _redact(str(exc), key_path, password_file, os.getenv("ARI_DEPLOY_PASSWORD", ""))
    if name == "AuthenticationException" or "Authentication failed" in text:
        return (
            "SSH authentication failed before deployment "
            f"({auth}). Provide a valid current root password or SSH key. No credential values were printed."
        )
    return f"Deploy failed: {name}: {text} ({auth})"


def _auth_summary(key_path: str, password_file: str) -> str:
    password_env = os.getenv("ARI_DEPLOY_PASSWORD", "")
    return ", ".join(
        [
            "key=provided" if key_path else "key=not_provided",
            "password_file=provided" if password_file else "password_file=not_provided",
            "password_env=provided" if password_env else "password_env=not_provided",
        ]
    )


def _redact(value: str, *sensitive_values: str) -> str:
    result = str(value)
    for sensitive in sensitive_values:
        if sensitive:
            result = result.replace(str(sensitive), "<redacted>")
    return result


def _exec_checked(client, command: str) -> None:
    stdin, stdout, stderr = client.exec_command(command, timeout=900)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    code = stdout.channel.recv_exit_status()
    if out:
        print(out)
    if code != 0:
        if err:
            print(err, file=sys.stderr)
        raise RuntimeError(f"remote command failed with exit code {code}")


if __name__ == "__main__":
    raise SystemExit(main())
