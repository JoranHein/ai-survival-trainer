from pathlib import Path


def test_pydantic_requirement_allows_python_314_compatible_wheels() -> None:
    requirements = Path(__file__).resolve().parents[1] / "requirements.txt"
    lines = [
        line.strip()
        for line in requirements.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    pydantic_lines = [line for line in lines if line.startswith("pydantic")]

    assert len(pydantic_lines) == 1
    requirement = pydantic_lines[0]
    assert requirement.startswith("pydantic>=")
    minimum = requirement.split(">=", 1)[1].split(",", 1)[0]
    major, minor, *_ = [int(part) for part in minimum.split(".")]
    assert (major, minor) >= (2, 12)
    assert "<3" in requirement
