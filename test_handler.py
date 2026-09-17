import json
from handler import pick, handler

def test_pick_returns_one_of_the_options():
    options = ["pizza", "tacos", "sushi"]
    assert pick(options) in options

# runs the whole function the way Lambda will, over a few real requests
SAMPLE_REQUESTS = [
    {"options": ["pizza", "tacos", "sushi"]},
    {"options": ["yes", "no"]},
    {"options": [str(n) for n in range(20)]},
]

def test_handler_answers_every_request_cleanly():
    for req in SAMPLE_REQUESTS:
        result = handler({"body": json.dumps(req)}, None)
        assert result["statusCode"] == 200
