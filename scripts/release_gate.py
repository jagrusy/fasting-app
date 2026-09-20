#!/usr/bin/env python3
"""Read-only GitHub release preflight. No signing credentials or remote mutations."""
import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


class GateError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise GateError(message)


REQUIRED_JOBS = ('SwiftLint', 'Build & Test', 'Release Policy Tests', 'CI Required')
LANES = ('beta', 'release', 'screenshots_upload')


def select_candidate(event_name, event, ref, actor, allowed_actors):
    require(ref == 'refs/heads/main', 'Distribution must run from main, never a PR or tag.')
    if event_name == 'workflow_run':
        run = event.get('workflow_run', {})
        require(event.get('action') == 'completed', 'CI has not completed.')
        require(run.get('event') == 'push' and run.get('head_branch') == 'main',
                'Automatic distribution requires a main push CI run.')
        require(run.get('conclusion') == 'success', 'CI did not succeed.')
        lane, run_id, sha = 'beta', str(run.get('id', '')), run.get('head_sha', '')
    elif event_name == 'workflow_dispatch':
        require(actor.lower() in allowed_actors, 'Actor is not an allowed manual release operator.')
        inputs = event.get('inputs', {})
        require('skip_tests' not in inputs, 'The skip_tests bypass is not supported.')
        lane, run_id, sha = inputs.get('lane'), inputs.get('ci_run_id', ''), inputs.get('commit_sha', '')
    else:
        raise GateError('Unsupported distribution event.')
    require(lane in LANES, 'Unsupported lane.')
    require(isinstance(run_id, str) and re.fullmatch(r'[1-9][0-9]*', run_id), 'CI run ID must be numeric.')
    require(isinstance(sha, str) and re.fullmatch(r'[0-9a-f]{40}', sha), 'Supply the complete lowercase commit SHA.')
    return {'lane': lane, 'ci_run_id': int(run_id), 'sha': sha,
            'environment': 'testflight' if lane == 'beta' else 'production'}


def validate_ci(candidate, repository, workflow, run, jobs, latest_runs, main_sha):
    require(candidate['sha'] == main_sha, 'Candidate is no longer the current main commit; select its current successful CI run.')
    require(workflow.get('path') == '.github/workflows/ci.yml' and workflow.get('state') == 'active',
            'Unexpected or disabled CI workflow.')
    require(run.get('workflow_id') == workflow.get('id'), 'Run does not belong to the required CI workflow.')
    require(run.get('id') == candidate['ci_run_id'], 'CI run identity mismatch.')
    require(run.get('head_repository', {}).get('full_name') == repository,
            'Fork CI cannot authorize distribution.')
    require(run.get('repository', {}).get('full_name') == repository, 'CI repository mismatch.')
    require(run.get('event') == 'push' and run.get('head_branch') == 'main', 'CI must be from a main push, not a PR.')
    require(run.get('head_sha') == candidate['sha'], 'Green CI is for a different commit.')
    require(run.get('status') == 'completed' and run.get('conclusion') == 'success', 'CI is missing, pending, failed or cancelled.')
    same_commit = [r for r in latest_runs if r.get('head_sha') == candidate['sha']]
    require(same_commit and max(r['id'] for r in same_commit) == run['id'],
            'A newer CI run exists for this commit; an older green run is insufficient.')
    for name in REQUIRED_JOBS:
        matches = [j for j in jobs if j.get('name') == name]
        require(len(matches) == 1, f'Required job is missing or ambiguous: {name}')
        job = matches[0]
        require(job.get('head_sha') == candidate['sha'], f'Job commit mismatch: {name}')
        require(job.get('status') == 'completed' and job.get('conclusion') == 'success',
                f'Required job did not pass: {name}')


def validate_deployment_environment(environment, expected_name, branch_policies):
    require(environment.get('name') == expected_name, f'Protected {expected_name} environment is missing.')
    require(type(environment.get('id')) is int and environment['id'] > 0,
            'Deployment environment identity is missing or malformed.')
    policy = environment.get('deployment_branch_policy') or {}
    require(policy.get('custom_branch_policies') is True and policy.get('protected_branches') is False,
            'Deployment must use an explicit selected-branch policy, not unrestricted/protected-branch fallback.')
    require(len(branch_policies) == 1 and branch_policies[0].get('name') == 'main'
            and branch_policies[0].get('type') == 'branch',
            'Deployment environment must allow only the main branch, with no tags or wildcard rules.')


def validate_environment(environment, allowed_actors):
    require(environment.get('name') == 'production', 'Protected production environment is missing.')
    require(type(environment.get('id')) is int and environment['id'] > 0,
            'Production environment identity is missing or malformed.')
    review_rules = [r for r in environment.get('protection_rules', []) if r.get('type') == 'required_reviewers']
    reviewers = [r for rule in review_rules for r in rule.get('reviewers', [])]
    require(any(r.get('type') == 'User' and r.get('reviewer', {}).get('login', '').lower() in allowed_actors
                for r in reviewers), 'Production must require an explicitly allowed human reviewer.')


def validate_approval(reviews, environment, allowed_actors, attempt):
    # A rerun can otherwise inherit an earlier approval while producing a new binary.
    require(attempt == 1, 'Start a new production dispatch instead of reusing a previous approval on rerun.')
    relevant = [r for r in reviews if any(e.get('id') == environment.get('id')
                for e in r.get('environments', []))]
    require(relevant and not any(r.get('state') == 'rejected' for r in relevant),
            'No valid production approval, or this run was rejected; use a fresh dispatch.')
    require(any(r.get('state') == 'approved' and r.get('user', {}).get('type') == 'User'
                and r.get('user', {}).get('login', '').lower() in allowed_actors for r in relevant),
            'Production requires approval by an allowed human, not a bot or bypass.')


class GitHub:
    def __init__(self, repository, token):
        require(re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository), 'Invalid repository identity.')
        require(bool(token), 'Missing read-only GitHub token.')
        self.base = f'https://api.github.com/repos/{repository}/'
        self.token = token

    def get(self, path):
        request = Request(self.base + path, headers={
            'Authorization': f'Bearer {self.token}', 'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'solstice-release-preflight',
        })
        try:
            with urlopen(request, timeout=20) as response:
                return json.load(response)
        except HTTPError as exc:
            raise GateError(f'GitHub verification unavailable (HTTP {exc.code}) for {path}; refusing distribution.') from None
        except (URLError, TimeoutError, json.JSONDecodeError):
            raise GateError(f'GitHub verification unavailable for {path}; refusing distribution.') from None

    def pages(self, path, key):
        items = []
        for page in range(1, 11):
            result = self.get(f'{path}{"&" if "?" in path else "?"}per_page=100&page={page}')
            batch = result[key]
            items.extend(batch)
            if len(batch) < 100:
                return items
        raise GateError('Verification pagination limit reached; refusing an incomplete check.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--verify-approval', action='store_true')
    args = parser.parse_args()
    env = os.environ
    repository = env['GITHUB_REPOSITORY']
    allowed = {s.strip().lower() for s in env.get('RELEASE_ACTORS', repository.split('/')[0]).split(',') if s.strip()}
    require(bool(allowed), 'Release operator allowlist is empty.')
    event = json.loads(Path(env['GITHUB_EVENT_PATH']).read_text())
    candidate = select_candidate(env['GITHUB_EVENT_NAME'], event, env['GITHUB_REF'], env['GITHUB_ACTOR'], allowed)
    api = GitHub(repository, env.get('GH_TOKEN', ''))
    workflow = api.get('actions/workflows/ci.yml')
    run = api.get(f'actions/runs/{candidate["ci_run_id"]}')
    attempt = run.get('run_attempt')
    require(isinstance(attempt, int) and attempt > 0, 'CI attempt identity is missing.')
    jobs = api.pages(f'actions/runs/{run["id"]}/attempts/{attempt}/jobs', 'jobs')
    query = urlencode({'branch': 'main', 'event': 'push', 'head_sha': candidate['sha']})
    latest = api.pages(f'actions/workflows/{workflow["id"]}/runs?{query}', 'workflow_runs')
    main_sha = api.get('git/ref/heads/main')['object']['sha']
    validate_ci(candidate, repository, workflow, run, jobs, latest, main_sha)
    # Re-read after job queries to detect a CI rerun started during verification.
    current_run = api.get(f'actions/runs/{run["id"]}')
    require(current_run.get('run_attempt') == attempt and current_run.get('status') == 'completed'
            and current_run.get('conclusion') == 'success', 'CI changed during verification.')
    target = candidate['environment']
    environment = api.get(f'environments/{target}')
    branch_policies = api.pages(f'environments/{target}/deployment-branch-policies', 'branch_policies')
    validate_deployment_environment(environment, target, branch_policies)
    if target == 'production':
        validate_environment(environment, allowed)
        if args.verify_approval:
            validate_approval(api.get(f'actions/runs/{env["GITHUB_RUN_ID"]}/approvals'), environment,
                              allowed, int(env['GITHUB_RUN_ATTEMPT']))
    output = env.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a') as stream:
            for key, value in candidate.items():
                stream.write(f'{key}={value}\n')
    summary = env.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as stream:
            stream.write(f'## Verified distribution source\n\nLane: `{candidate["lane"]}`\n\n'
                         f'Commit: `{candidate["sha"]}`\n\nCI run: `{run["id"]}`, attempt `{attempt}`.\n\n'
                         'Production approval covers submission/publication from this source. '
                         'Promotion of an already tested TestFlight binary is separate roadmap work; '
                         'this guard does not claim binary equivalence.\n')
    print(f'Verified {candidate["lane"]} source {candidate["sha"]} against CI {run["id"]}.')


if __name__ == '__main__':
    try:
        main()
    except (GateError, KeyError, TypeError, ValueError) as exc:
        print(f'Release blocked: {exc}', file=sys.stderr)
        sys.exit(1)
