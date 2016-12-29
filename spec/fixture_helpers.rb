module FixtureHelpers
  FIXTURES_PATH = File.join(File.dirname(__FILE__), 'fixtures')

  def fixtures_path(cls)
    path = File.join(FIXTURES_PATH, cls.to_s)
  end

  def fixture_path(cls, *parts)
    path = File.join(FIXTURES_PATH, cls.to_s, *parts)
  end
end
