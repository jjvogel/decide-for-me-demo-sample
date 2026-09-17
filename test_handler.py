import json
from handler import pick, handler

def test_pick_returns_one_of_the_options():
    options = ["pizza", "tacos", "sushi"]
    assert pick(options) in options

def test_pick_respects_exclude():
    result = pick(["pizza", "tacos", "sushi"], exclude=["sushi"])
    assert result in ["pizza", "tacos"]

# runs the whole function the way Lambda will, over a few real requests
SAMPLE_REQUESTS = [
    {"options": ["pizza", "tacos", "sushi"]},
    {"options": ["pizza", "tacos", "sushi"], "exclude": ["sushi"]},
    {"options": ["coffee", "tea"], "exclude": ["coffee", "tea"]},   # changed their mind on both
]

def test_handler_answers_every_request_cleanly():
    for req in SAMPLE_REQUESTS:
        result = handler({"body": json.dumps(req)}, None)
        assert result["statusCode"] == 200
