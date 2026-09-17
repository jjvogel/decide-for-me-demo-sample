# Decide for Me

A one-file Lambda app with a CI/CD pipeline in front of it. Send it a list of options, it picks one. Every push to `main` runs the tests, and if they pass, GitHub Actions ships the new code to Lambda. If they fail, nothing ships.

This is the demo from the video **I Stopped Deploying By Hand (CI/CD for Beginners)** on the AWS Developers YouTube channel and its companion blog post on AWS Builder Center.

<!-- TODO: add video and blog links -->

## The three files

| File | What it is |
| --- | --- |
| `handler.py` | The app. `pick()` chooses from a list, optionally excluding some. `handler()` is the Lambda entry point. |
| `test_handler.py` | Two unit tests plus one test that runs the whole handler over realistic requests. |
| `.github/workflows/deploy.yml` | The pipeline. A `test` job, then a `deploy` job that `needs: test`. |

## Run it yourself

You need the AWS CLI configured with credentials that can create IAM roles and Lambda functions, plus a GitHub account.

1. Fork this repo and clone your fork.

2. Create the AWS side. From the repo root:

   ```bash
   GH_OWNER=your-github-user ./setup/setup.sh
   ```

   This registers GitHub as an OIDC identity provider in your account (once per account), creates the Lambda execution role and the `decide-for-me` function, and creates the `decide-for-me-deploy` role that GitHub Actions assumes. The trust policy is pinned to your fork's `main` branch and the permission policy allows only `lambda:UpdateFunctionCode` on that one function.

   The script prints a role ARN when it finishes.

3. Paste that ARN into `.github/workflows/deploy.yml` under `role-to-assume`, replacing the account ID that's there.

4. Commit and push to `main`. Open the Actions tab and watch `test` run, then `deploy`.

5. Call the function:

   ```bash
   aws lambda invoke --function-name decide-for-me \
     --cli-binary-format raw-in-base64-out \
     --payload '{"body":"{\"options\":[\"pizza\",\"tacos\",\"sushi\"]}"}' response.json
   jq -r '.body | fromjson' response.json
   ```

   The payload is wrapped in `body` because the handler reads `event["body"]`, the shape a Lambda Function URL would send.

## Why there are two `sub` patterns in the trust policy

GitHub changed the default OIDC subject claim for repositories created after July 15, 2026 to an immutable format with numeric IDs: `repo:OWNER@<owner_id>/REPO@<repo_id>:ref:refs/heads/main`. Older repos keep the classic `repo:OWNER/REPO:ref:refs/heads/main`. Your fork is a new repo, so it gets the new format. `setup/trust-deploy.template.json` lists both patterns in a `StringLike` so the role works either way. If you only list the classic pattern on a new repo, every deploy fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.

## Watch the gate work

Commit `b43e538` adds the exclude feature with a bug: a request that excludes every option produces an empty list, and `random.choice([])` raises `IndexError`. The test job goes red and deploy is skipped. The next commit fixes the code (not the test) and the pipeline goes green.

To see it yourself, push a change that breaks a test and check the Actions tab. Deploy stays gray.

## Tear it down

```bash
./setup/teardown.sh
```

Removes the deploy role, the function, the execution role and the log group. It leaves the account-wide OIDC provider in place unless you set `DELETE_OIDC_PROVIDER=yes`, since other repos in the account may use it.

## License

MIT
