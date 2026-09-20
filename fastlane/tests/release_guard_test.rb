require 'minitest/autorun'
require_relative '../release_guard'

class ReleaseGuardTest < Minitest::Test
  SHA = 'a' * 40

  def environment
    { 'GITHUB_ACTIONS' => 'true', 'SOLSTICE_VERIFIED_LANE' => 'beta', 'SOLSTICE_VERIFIED_SHA' => SHA }
  end

  def test_verified_checkout_and_lane
    SolsticeReleaseGuard.verify!('beta', env: environment, head_sha: "#{SHA}\n")
  end

  def test_local_lane_cannot_publish
    assert_raises(RuntimeError) { SolsticeReleaseGuard.verify!('beta', env: {}, head_sha: SHA) }
  end

  def test_beta_cannot_be_changed_to_release
    assert_raises(RuntimeError) { SolsticeReleaseGuard.verify!('release', env: environment, head_sha: SHA) }
  end

  def test_unverified_checkout_is_rejected
    assert_raises(RuntimeError) { SolsticeReleaseGuard.verify!('beta', env: environment, head_sha: 'b' * 40) }
  end

  def test_missing_or_malformed_sha_is_rejected
    [nil, '', 'main', SHA + "\nother"].each do |sha|
      assert_raises(RuntimeError) do
        SolsticeReleaseGuard.verify!('beta', env: environment.merge('SOLSTICE_VERIFIED_SHA' => sha), head_sha: SHA)
      end
    end
  end
end
