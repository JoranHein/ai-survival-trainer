import importlib.util
import tarfile
from pathlib import Path


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "deploy_gateway.py"
    spec = importlib.util.spec_from_file_location("deploy_gateway", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_deploy_package_excludes_env_and_local_secret_files(tmp_path):
    tool = _load_tool()
    root = tmp_path / "ai_gateway"
    (root / "app").mkdir(parents=True)
    (root / "app" / "main.py").write_text("print('ok')\n", encoding="utf-8")
    (root / "scripts").mkdir()
    (root / "scripts" / "install_server.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    (root / "scripts" / "benchmark_prediction_models.py").write_text("print('bench')\n", encoding="utf-8")
    (root / "systemd").mkdir()
    (root / "systemd" / "ari-ai-gateway.service").write_text("[Service]\n", encoding="utf-8")
    (root / "requirements.txt").write_text("fastapi\n", encoding="utf-8")
    (root / ".env").write_text("GAME_AI_API_KEY=secret\n", encoding="utf-8")
    (root / ".env.example").write_text("GAME_AI_API_KEY=replace\n", encoding="utf-8")
    (root / "deploy.local.json").write_text('{"password":"secret"}\n', encoding="utf-8")
    (root / "__pycache__").mkdir()
    (root / "__pycache__" / "main.pyc").write_bytes(b"compiled")

    archive = tool.build_package(root, tmp_path / "gateway.tar.gz")

    with tarfile.open(archive, "r:gz") as package:
        names = sorted(package.getnames())

    assert "app/main.py" in names
    assert "scripts/install_server.sh" in names
    assert "scripts/benchmark_prediction_models.py" in names
    assert "systemd/ari-ai-gateway.service" in names
    assert "requirements.txt" in names
    assert ".env.example" in names
    assert ".env" not in names
    assert "deploy.local.json" not in names
    assert "__pycache__/main.pyc" not in names


def test_remote_install_command_preserves_env_and_verifies_observer_endpoints():
    tool = _load_tool()

    command = tool.remote_install_command("/opt/ari-ai-server", "/tmp/ari-ai-gateway.tar.gz")

    assert "cp .env /tmp/ari-ai-server.env.backup" in command
    assert "tar -xzf /tmp/ari-ai-gateway.tar.gz -C /opt/ari-ai-server" in command
    assert "mv /tmp/ari-ai-server.env.backup .env" in command
    assert "bash scripts/install_server.sh" in command
    assert "systemctl restart ari-ai-gateway" in command
    assert "/scribe" in command
    assert "/library-reflection" not in command
    assert "systemctl restart ollama" in command
    assert "sleep 7" in command
    assert "GAME_AI_API_KEY" in command
    assert "set -euo pipefail" in command


def test_install_server_configures_ollama_parallel_runtime():
    script = (Path(__file__).resolve().parents[1] / "scripts" / "install_server.sh").read_text(encoding="utf-8")

    assert "OLLAMA_NUM_PARALLEL" in script
    assert "OLLAMA_MAX_LOADED_MODELS" in script
    assert "ensure_env_value OLLAMA_MAX_LOADED_MODELS 3" in script
    assert 'Environment="OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-3}"' in script
    assert "OLLAMA_MAX_QUEUE" in script
    assert "/etc/systemd/system/ollama.service.d" in script
    assert "systemctl daemon-reload" in script
    assert "systemctl restart ollama" in script


def test_check_ssh_only_skips_packaging_and_upload(monkeypatch, tmp_path, capsys):
    tool = _load_tool()
    root = tmp_path / "ai_gateway"
    root.mkdir()
    calls = []

    def fake_check_ssh_auth(**kwargs):
        calls.append(kwargs)

    def fail_build_package(*_args, **_kwargs):
        raise AssertionError("check-ssh-only must not build a package")

    monkeypatch.setattr(tool, "check_ssh_auth", fake_check_ssh_auth)
    monkeypatch.setattr(tool, "build_package", fail_build_package)

    result = tool.main([
        "--root",
        str(root),
        "--host",
        "example.test",
        "--user",
        "root",
        "--check-ssh-only",
    ])

    assert result == 0
    assert calls and calls[0]["host"] == "example.test"
    assert "SSH auth check passed" in capsys.readouterr().out


def test_deploy_error_message_sanitizes_auth_inputs(tmp_path):
    tool = _load_tool()
    password_file = tmp_path / "very-secret-password.txt"
    password_file.write_text("do-not-print", encoding="utf-8")

    class AuthenticationException(Exception):
        pass

    message = tool.format_deploy_error(
        AuthenticationException("Authentication failed."),
        key_path="",
        password_file=str(password_file),
    )

    assert "SSH authentication failed" in message
    assert "password_file=provided" in message
    assert str(password_file) not in message
    assert "do-not-print" not in message
