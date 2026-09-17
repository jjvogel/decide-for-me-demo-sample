import json
import random

def pick(options, exclude=None):
    if exclude:
        options = [o for o in options if o not in exclude]
    if not options:
        return None
    return random.choice(options)

def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    options = body.get("options", [])
    exclude = body.get("exclude", [])
    choice = pick(options, exclude)
    if choice is None:
        return {"statusCode": 200, "body": json.dumps({"choice": None, "message": "nothing left to pick"})}
    return {"statusCode": 200, "body": json.dumps({"choice": choice})}
