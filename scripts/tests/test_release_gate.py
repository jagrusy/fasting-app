import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError

spec = importlib.util.spec_from_file_location('release_gate', Path(__file__).parents[1] / 'release_gate.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

SHA = 'a' * 40
REPO = 'jagrusy/fasting-app'
ALLOWED = {'jagrusy'}


class ReleasePolicyTests(unittest.TestCase):
    def setUp(self):
        self.candidate = {'lane': 'beta', 'ci_run_id': 42, 'sha': SHA, 'environment': 'testflight'}
        self.workflow = {'id': 9, 'path': '.github/workflows/ci.yml', 'state': 'active'}
        self.run = {'id': 42, 'workflow_id': 9, 'repository': {'full_name': REPO},
                    'head_repository': {'full_name': REPO}, 'event': 'push', 'head_branch': 'main',
                    'head_sha': SHA, 'status': 'completed', 'conclusion': 'success', 'run_attempt': 1}
        self.jobs = [{'name': name, 'head_sha': SHA, 'status': 'completed', 'conclusion': 'success'}
                     for name in gate.REQUIRED_JOBS]
        self.latest = [copy.deepcopy(self.run)]
        self.environment = {'id': 123, 'name': 'production', 'protection_rules': [
            {'type': 'required_reviewers', 'reviewers': [{'type': 'User', 'reviewer': {'login': 'jagrusy'}}]}]}
        self.review = {'state': 'approved', 'environments': [{'id': 123, 'name': 'production'}],
                       'user': {'login': 'jagrusy', 'type': 'User'}}

    def verify(self, main_sha=SHA):
        gate.validate_ci(self.candidate, REPO, self.workflow, self.run, self.jobs, self.latest, main_sha)

    def test_current_successful_main_is_accepted(self):
        self.verify()

    def test_failed_pending_skipped_cancelled_ci_rejected(self):
        for conclusion in ('failure', 'cancelled', 'skipped', 'neutral', None, 'timed_out'):
            with self.subTest(conclusion=conclusion):
                self.run['conclusion'] = conclusion
                with self.assertRaises(gate.GateError):
                    self.verify()

    def test_running_ci_cannot_reuse_success_conclusion(self):
        self.run['status'] = 'in_progress'
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_sha_mismatch_rejected(self):
        self.run['head_sha'] = 'b' * 40
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_main_advanced_while_waiting_rejected(self):
        with self.assertRaises(gate.GateError):
            self.verify(main_sha='b' * 40)

    def test_pr_or_other_branch_ci_rejected(self):
        for key, value in [('event', 'pull_request'), ('head_branch', 'feature')]:
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = value
                with self.assertRaises(gate.GateError):
                    self.verify()
                self.run[key] = original

    def test_fork_and_repository_identity_rejected(self):
        for key in ('head_repository', 'repository'):
            with self.subTest(key=key):
                self.run[key]['full_name'] = 'someone/fork'
                with self.assertRaises(gate.GateError):
                    self.verify()
                self.run[key]['full_name'] = REPO

    def test_wrong_workflow_or_run_rejected(self):
        for key, value in [('workflow_id', 10), ('id', 999)]:
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = value
                with self.assertRaises(gate.GateError):
                    self.verify()
                self.run[key] = original

    def test_disabled_or_wrong_workflow_path_rejected(self):
        for key, value in [('path', '.github/workflows/other.yml'), ('state', 'disabled_manually')]:
            with self.subTest(key=key):
                original = self.workflow[key]
                self.workflow[key] = value
                with self.assertRaises(gate.GateError):
                    self.verify()
                self.workflow[key] = original

    def test_newer_failed_or_running_run_invalidates_old_success(self):
        self.latest.append(dict(self.run, id=43, conclusion='failure'))
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_missing_ci_listing_fails_closed(self):
        self.latest = []
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_every_required_job_must_pass(self):
        for job in self.jobs:
            for result in ('skipped', 'cancelled', 'failure', 'neutral', None):
                with self.subTest(job=job['name'], result=result):
                    job['conclusion'] = result
                    with self.assertRaises(gate.GateError):
                        self.verify()
            job['conclusion'] = 'success'

    def test_missing_or_duplicate_required_job_rejected(self):
        jobs = copy.deepcopy(self.jobs)
        for position in range(len(jobs)):
            with self.subTest(position=position):
                self.jobs = jobs[:position] + jobs[position + 1:]
                with self.assertRaises(gate.GateError):
                    self.verify()
        self.jobs = jobs + [jobs[0]]
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_job_sha_mismatch_rejected(self):
        self.jobs[0]['head_sha'] = 'b' * 40
        with self.assertRaises(gate.GateError):
            self.verify()

    def test_automatic_beta_only_for_completed_main_push(self):
        event = {'action': 'completed', 'workflow_run': self.run}
        self.assertEqual(gate.select_candidate('workflow_run', event, 'refs/heads/main', 'bot', ALLOWED), self.candidate)
        event['action'] = 'requested'
        with self.assertRaises(gate.GateError):
            gate.select_candidate('workflow_run', event, 'refs/heads/main', 'bot', ALLOWED)

    def test_manual_release_requires_allowed_actor_and_exact_input(self):
        event = {'inputs': {'lane': 'release', 'ci_run_id': '42', 'commit_sha': SHA}}
        result = gate.select_candidate('workflow_dispatch', event, 'refs/heads/main', 'jagrusy', ALLOWED)
        self.assertEqual(result['environment'], 'production')
        with self.assertRaises(gate.GateError):
            gate.select_candidate('workflow_dispatch', event, 'refs/heads/main', 'unapproved-bot', ALLOWED)

    def test_screenshots_are_also_production_mutations(self):
        event = {'inputs': {'lane': 'screenshots_upload', 'ci_run_id': '42', 'commit_sha': SHA}}
        result = gate.select_candidate('workflow_dispatch', event, 'refs/heads/main', 'jagrusy', ALLOWED)
        self.assertEqual(result['environment'], 'production')

    def test_untrusted_ref_and_unsupported_events_rejected(self):
        event = {'inputs': {'lane': 'beta', 'ci_run_id': '42', 'commit_sha': SHA}}
        for ref in ('refs/pull/1/merge', 'refs/heads/feature', 'refs/tags/v1'):
            with self.subTest(ref=ref), self.assertRaises(gate.GateError):
                gate.select_candidate('workflow_dispatch', event, ref, 'jagrusy', ALLOWED)
        with self.assertRaises(gate.GateError):
            gate.select_candidate('push', event, 'refs/heads/main', 'jagrusy', ALLOWED)

    def test_invalid_input_and_skip_bypass_rejected(self):
        for key, value in [('lane', 'beta; echo bad'), ('ci_run_id', '../42'),
                           ('commit_sha', 'main'), ('skip_tests', 'false')]:
            event = {'inputs': {'lane': 'beta', 'ci_run_id': '42', 'commit_sha': SHA}}
            event['inputs'][key] = value
            with self.subTest(key=key), self.assertRaises(gate.GateError):
                gate.select_candidate('workflow_dispatch', event, 'refs/heads/main', 'jagrusy', ALLOWED)

    def test_production_requires_configured_human_reviewer(self):
        gate.validate_environment(self.environment, ALLOWED)
        for environment in ({}, {'name': 'production', 'protection_rules': []},
                            {'name': 'production', 'protection_rules': [{'type': 'wait_timer'}]}):
            with self.subTest(environment=environment), self.assertRaises(gate.GateError):
                gate.validate_environment(environment, ALLOWED)

    def test_unlisted_reviewer_rejected(self):
        with self.assertRaises(gate.GateError):
            gate.validate_environment(self.environment, {'different-user'})

    def test_environment_must_have_a_real_identity_for_approval_matching(self):
        for value in (None, '', 0, True, '123'):
            with self.subTest(value=value), self.assertRaises(gate.GateError):
                gate.validate_environment(dict(self.environment, id=value), ALLOWED)

    def deployment_environment(self, name='testflight'):
        return dict(copy.deepcopy(self.environment), name=name, deployment_branch_policy={
            'custom_branch_policies': True, 'protected_branches': False})

    def test_exact_main_branch_environment_is_accepted_for_each_lane(self):
        for name in ('testflight', 'production'):
            with self.subTest(name=name):
                gate.validate_deployment_environment(self.deployment_environment(name), name,
                                                     [{'name': 'main', 'type': 'branch'}])

    def test_environment_cannot_allow_tags_wildcards_extra_rules_or_unknown_types(self):
        variants = [[], [{'name': 'main', 'type': 'tag'}], [{'name': '*', 'type': 'branch'}],
                    [{'name': 'main'}], [{'name': 'feature', 'type': 'branch'}],
                    [{'name': 'main', 'type': 'branch'}, {'name': 'main', 'type': 'tag'}],
                    [{'name': 'main', 'type': 'branch'}, {'name': 'feature/*', 'type': 'branch'}]]
        for policies in variants:
            with self.subTest(policies=policies), self.assertRaises(gate.GateError):
                gate.validate_deployment_environment(self.deployment_environment(), 'testflight', policies)

    def test_unrestricted_protected_only_or_malformed_environment_mode_rejected(self):
        for policy in (None, {}, {'protected_branches': True, 'custom_branch_policies': False},
                       {'protected_branches': False, 'custom_branch_policies': False},
                       {'protected_branches': False, 'custom_branch_policies': 'true'}):
            environment = dict(self.deployment_environment(), deployment_branch_policy=policy)
            with self.subTest(policy=policy), self.assertRaises(gate.GateError):
                gate.validate_deployment_environment(environment, 'testflight', [{'name': 'main', 'type': 'branch'}])

    def test_beta_environment_identity_is_verified_too(self):
        for changes in ({'name': 'other'}, {'id': None}, {'id': 0}, {'id': True}, {'id': '123'}):
            with self.subTest(changes=changes), self.assertRaises(gate.GateError):
                gate.validate_deployment_environment(dict(self.deployment_environment(), **changes),
                                                     'testflight', [{'name': 'main', 'type': 'branch'}])

    def run_preflight(self, lane='beta', policies=None, environment_missing=False,
                      verify_approval=False, reviews=None):
        target = 'testflight' if lane == 'beta' else 'production'
        responses = {'actions/workflows/ci.yml': self.workflow, 'actions/runs/42': self.run,
                     'git/ref/heads/main': {'object': {'sha': SHA}},
                     f'environments/{target}': self.deployment_environment(target),
                     'actions/runs/99/approvals': [self.review] if reviews is None else reviews}

        def get(path):
            if environment_missing and path == f'environments/{target}':
                raise gate.GateError('Environment unavailable')
            return responses[path]

        def pages(path, key):
            if key == 'jobs':
                return self.jobs
            if key == 'workflow_runs':
                return self.latest
            self.assertEqual(path, f'environments/{target}/deployment-branch-policies')
            self.assertEqual(key, 'branch_policies')
            return [{'name': 'main', 'type': 'branch'}] if policies is None else policies

        with tempfile.TemporaryDirectory() as directory:
            event_path, output = Path(directory) / 'event.json', Path(directory) / 'output'
            event_path.write_text(json.dumps({'inputs': {'lane': lane, 'ci_run_id': '42', 'commit_sha': SHA}}))
            env = {'GITHUB_REPOSITORY': REPO, 'GITHUB_EVENT_PATH': str(event_path),
                   'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REF': 'refs/heads/main',
                   'GITHUB_ACTOR': 'jagrusy', 'GH_TOKEN': 'fixture-token', 'GITHUB_OUTPUT': str(output),
                   'GITHUB_RUN_ID': '99', 'GITHUB_RUN_ATTEMPT': '1'}
            argv = ['release_gate.py'] + (['--verify-approval'] if verify_approval else [])
            with patch.dict(gate.os.environ, env, clear=True), patch.object(gate.sys, 'argv', argv), \
                    patch.object(gate, 'GitHub') as api_class:
                api_class.return_value.get.side_effect = get
                api_class.return_value.pages.side_effect = pages
                try:
                    gate.main()
                except gate.GateError:
                    self.assertFalse(output.exists(), 'Rejected preflight must not admit a publishing job')
                    raise
            self.assertIn(f'environment={target}', output.read_text())

    def test_beta_preflight_checks_testflight_without_requiring_production(self):
        self.run_preflight()

    def test_both_preflight_passes_reject_unsafe_or_missing_target_environment(self):
        for lane in gate.LANES:
            for verify_approval in (False, True):
                for failure in ({'policies': []}, {'environment_missing': True}):
                    with self.subTest(lane=lane, recheck=verify_approval, failure=failure), self.assertRaises(gate.GateError):
                        self.run_preflight(lane, verify_approval=verify_approval, **failure)

    def test_production_recheck_requires_approval_after_environment_validation(self):
        self.run_preflight('release', verify_approval=True)
        with self.assertRaises(gate.GateError):
            self.run_preflight('release', verify_approval=True, reviews=[])

    def test_approved_production_accepted(self):
        gate.validate_approval([self.review], self.environment, ALLOWED, 1)

    def test_no_approval_rejection_wrong_environment_bot_or_other_actor_rejected(self):
        variants = [[], [dict(self.review, state='rejected')],
                    [dict(self.review, environments=[{'id': 999}])],
                    [dict(self.review, user={'login': 'jagrusy', 'type': 'Bot'})],
                    [dict(self.review, user={'login': 'stranger', 'type': 'User'})]]
        for reviews in variants:
            with self.subTest(reviews=reviews), self.assertRaises(gate.GateError):
                gate.validate_approval(reviews, self.environment, ALLOWED, 1)

    def test_rejection_cannot_be_overridden_in_same_run(self):
        with self.assertRaises(gate.GateError):
            gate.validate_approval([self.review, dict(self.review, state='rejected')], self.environment, ALLOWED, 1)

    def test_rerun_cannot_reuse_production_approval(self):
        with self.assertRaises(gate.GateError):
            gate.validate_approval([self.review], self.environment, ALLOWED, 2)

    def test_remote_verification_errors_fail_closed_without_token_disclosure(self):
        api = gate.GitHub(REPO, 'test-token-do-not-log')
        errors = [HTTPError('https://api.github.com', 404, 'Missing', {}, None),
                  HTTPError('https://api.github.com', 403, 'Denied', {}, None), URLError('offline')]
        for error in errors:
            with self.subTest(error=type(error)), patch.object(gate, 'urlopen', side_effect=error):
                with self.assertRaises(gate.GateError) as raised:
                    api.get('environments/production')
                self.assertNotIn('test-token-do-not-log', str(raised.exception))

    def test_pagination_never_silently_truncates_verification(self):
        api = gate.GitHub(REPO, 'test-token')
        with patch.object(api, 'get', return_value={'jobs': [{}] * 100}):
            with self.assertRaises(gate.GateError):
                api.pages('actions/runs/42/jobs', 'jobs')


if __name__ == '__main__':
    unittest.main()
