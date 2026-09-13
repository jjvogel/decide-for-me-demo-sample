import json
import random

def pick(options):
    return random.choice(options)

def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    options = body.get("options", [])
    choice = pick(options)
    return {"statusCode": 200, "body": json.dumps({"choice": choice})}
