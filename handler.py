import json
import random

def pick(a, b):
    return random.choice([a, b])

def handler(event, context):
    body = json.loads(event.get("body") or "{}")
    choice = pick(body["a"], body["b"])
    return {"statusCode": 200, "body": json.dumps({"choice": choice})}
