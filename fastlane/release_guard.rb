# This prevents accidental direct lane invocation. GitHub protection and the verified
# workflow are the authorization boundary; environment variables are not credentials.
module SolsticeReleaseGuard
  def self.verify!(lane, env:, head_sha:)
    raise 'Distribution requires the verified GitHub Actions workflow.' unless env['GITHUB_ACTIONS'] == 'true'
    raise 'Verified lane does not match the requested lane.' unless env['SOLSTICE_VERIFIED_LANE'] == lane
    sha = env['SOLSTICE_VERIFIED_SHA']
    unless sha&.match?(/\A[0-9a-f]{40}\z/) && sha == head_sha.strip
      raise 'Application checkout does not match the CI-verified commit.'
    end
  end
end
