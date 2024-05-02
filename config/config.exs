import Config

if config_env() == :test do
  config :tracee,
    assert_receive_timeout: 10,
    refute_receive_timeout: 10
end
