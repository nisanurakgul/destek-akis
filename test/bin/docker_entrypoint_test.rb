require "test_helper"
require "open3"
require "tmpdir"

# Runs bin/docker-entrypoint with a fake ./bin/rails that only records the
# commands it receives, so no database is touched. Checks that demo data is
# added on boot only when DEMO_SEED_ON_BOOT=1.
class DockerEntrypointTest < ActiveSupport::TestCase
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint").to_s

  FAKE_RAILS = <<~BASH
    #!/bin/bash
    echo "$* demo_in_production=${DEMO_SEED_IN_PRODUCTION:-}" >> calls.log
    if [ "$1" == "db:prepare" ]; then exit "${FAKE_PREPARE_EXIT:-0}"; fi
    if [ "$1" == "demo:seed" ]; then exit "${FAKE_SEED_EXIT:-0}"; fi
    exit 0
  BASH

  # Runs the script directly (as Docker does), so its "#!/bin/bash -e" line applies.
  # Returns [calls recorded by the fake rails, exit status, stderr].
  def run_entrypoint(env = {}, command: [ "./bin/rails", "server" ])
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      fake = File.join(dir, "bin/rails")
      File.write(fake, FAKE_RAILS)
      File.chmod(0o755, fake)

      clean_env = { "DEMO_SEED_ON_BOOT" => nil, "DEMO_SEED_IN_PRODUCTION" => nil }
      _out, err, status = Open3.capture3(clean_env.merge(env), ENTRYPOINT, *command, chdir: dir)
      log = File.join(dir, "calls.log")
      [ File.exist?(log) ? File.readlines(log, chomp: true) : [], status, err ]
    end
  end

  test "without DEMO_SEED_ON_BOOT the server starts as before, with no demo seed" do
    calls, status, = run_entrypoint

    assert status.success?
    assert_equal [ "db:prepare demo_in_production=", "server demo_in_production=" ], calls
  end

  test "DEMO_SEED_ON_BOOT=1 adds demo data after db:prepare and before the server" do
    calls, status, = run_entrypoint({ "DEMO_SEED_ON_BOOT" => "1" })

    assert status.success?
    assert_equal [ "db:prepare demo_in_production=",
                   "demo:seed demo_in_production=1",
                   "server demo_in_production=" ], calls
  end

  test "only the exact value 1 turns the demo seed on" do
    [ "0", "true", "yes", "" ].each do |value|
      calls, = run_entrypoint({ "DEMO_SEED_ON_BOOT" => value })
      assert calls.none? { |call| call.start_with?("demo:seed") }, "DEMO_SEED_ON_BOOT=#{value.inspect}"
    end
  end

  test "a failing demo seed does not stop the server from starting" do
    calls, status, err = run_entrypoint({ "DEMO_SEED_ON_BOOT" => "1", "FAKE_SEED_EXIT" => "1" })

    assert status.success?
    assert_equal "server demo_in_production=", calls.last
    assert_match "Demo seed failed", err
  end

  test "a failing db:prepare still stops the boot and skips the demo seed" do
    calls, status, = run_entrypoint({ "DEMO_SEED_ON_BOOT" => "1", "FAKE_PREPARE_EXIT" => "1" })

    assert_not status.success?
    assert_equal [ "db:prepare demo_in_production=" ], calls
  end

  test "other commands run without db:prepare or demo seed" do
    calls, status, = run_entrypoint({ "DEMO_SEED_ON_BOOT" => "1" }, command: [ "./bin/rails", "console" ])

    assert status.success?
    assert_equal [ "console demo_in_production=" ], calls
  end
end
