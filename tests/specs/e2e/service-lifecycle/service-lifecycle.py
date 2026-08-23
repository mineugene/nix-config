import json


def container(stack):
    return json.loads(machine.succeed(f"docker inspect lifecycle-{stack}"))[0]


def assert_running(stack, version):
    state = container(stack)
    assert state["State"]["Running"], state
    assert state["Config"]["Labels"]["lifecycle-version"] == version, state
    return state["Id"]


def assert_environment(value):
    assert f"FIXTURE_VALUE={value}" in container("beta")["Config"]["Env"]


def assert_clean():
    machine.fail("docker inspect lifecycle-alpha")
    machine.fail("docker inspect lifecycle-beta")
    machine.fail("docker network inspect lifecycle-shared")


start_all()

with subtest("boot starts the prerequisite before the dependent stack"):
    machine.wait_for_unit("docker-registry.service")
    machine.wait_for_open_port(5000)
    machine.wait_for_unit("compose-beta.service")
    machine.wait_for_unit("compose-alpha.service")
    assert_running("alpha", "one")
    original_image = container("alpha")["Image"]
    beta_id = assert_running("beta", "one")
    assert_environment("initial")
    assert machine.succeed("docker exec lifecycle-beta cat /fixture/config.txt") == (
        "declarative fixture\n"
    )
    alpha_started = int(
        machine.succeed(
            "systemctl show compose-alpha -p ActiveEnterTimestampMonotonic --value"
        )
    )
    beta_started = int(
        machine.succeed(
            "systemctl show compose-beta -p ActiveEnterTimestampMonotonic --value"
        )
    )
    assert 0 < alpha_started <= beta_started
    machine.succeed("docker push localhost:5000/lifecycle-fixture:latest")

with subtest("reload is idempotent and applies a changed environment file"):
    machine.succeed("systemctl reload compose-beta")
    assert assert_running("beta", "one") == beta_id
    machine.succeed("rm /etc/lifecycle.env")
    machine.succeed("printf 'FIXTURE_VALUE=reloaded\\n' > /etc/lifecycle.env")
    machine.succeed("systemctl reload compose-beta")
    assert_environment("reloaded")
    assert assert_running("beta", "one") != beta_id

with subtest("restart restores declarative extra files and recreates containers"):
    beta_id = container("beta")["Id"]
    machine.succeed("printf 'damaged\\n' > /var/lib/compose/beta/nested/config.txt")
    machine.succeed("systemctl restart compose-beta")
    assert assert_running("beta", "one") != beta_id
    assert machine.succeed("docker exec lifecycle-beta cat /fixture/config.txt") == (
        "declarative fixture\n"
    )
    assert_environment("reloaded")

with subtest("stop removes containers and owned networks, not external networks"):
    machine.succeed("systemctl stop compose-beta")
    machine.fail("docker inspect lifecycle-beta")
    assert_running("alpha", "one")
    machine.succeed("docker network inspect lifecycle-shared")
    machine.succeed("systemctl stop compose-alpha")
    assert_clean()
    machine.succeed("systemctl start compose-beta")
    assert_running("alpha", "one")
    assert_running("beta", "one")

with subtest("a failed startup can recover after its environment file returns"):
    machine.succeed("systemctl stop compose-beta")
    machine.succeed("mv /etc/lifecycle.env /etc/lifecycle.env.saved")
    machine.fail("systemctl start compose-beta")
    machine.succeed("systemctl is-failed compose-beta")
    machine.fail("docker inspect lifecycle-beta")
    assert_running("alpha", "one")
    machine.succeed("mv /etc/lifecycle.env.saved /etc/lifecycle.env")
    machine.succeed("systemctl start compose-beta")
    machine.wait_for_unit("compose-beta.service")
    assert_running("beta", "one")
    assert_environment("reloaded")

with subtest("stopping a required stack stops its dependent before cleanup"):
    machine.succeed("systemctl stop compose-alpha")
    machine.wait_until_fails("systemctl is-active compose-beta")
    assert_clean()
    machine.succeed("systemctl start compose-beta")
    assert_running("alpha", "one")
    assert_running("beta", "one")

with subtest("Docker restart restarts both public Compose services"):
    alpha_id = container("alpha")["Id"]
    beta_id = container("beta")["Id"]
    machine.succeed("systemctl restart docker")
    machine.wait_for_unit("compose-alpha.service")
    machine.wait_for_unit("compose-beta.service")
    assert assert_running("alpha", "one") != alpha_id
    assert assert_running("beta", "one") != beta_id

with subtest("per-stack update pulls and recreates only the selected stack"):
    alpha_id = container("alpha")["Id"]
    beta_id = container("beta")["Id"]
    machine.succeed(
        "docker tag localhost:5000/lifecycle-fixture:next "
        "localhost:5000/lifecycle-fixture:latest"
    )
    machine.succeed("docker push localhost:5000/lifecycle-fixture:latest")
    machine.succeed(f"docker tag {original_image} localhost:5000/lifecycle-fixture:latest")
    machine.succeed("systemctl start compose-alpha-update")
    assert assert_running("alpha", "two") != alpha_id
    assert assert_running("beta", "one") == beta_id

with subtest("aggregate update reports failures and still attempts every stack"):
    alpha_id = container("alpha")["Id"]
    machine.succeed("systemctl stop docker-registry")
    machine.fail("systemctl start compose-update")
    for unit in ("compose-alpha-update", "compose-beta-update", "compose-update"):
        assert machine.succeed(f"systemctl show {unit} -p Result --value").strip() == (
            "exit-code"
        )
    assert assert_running("alpha", "two") == alpha_id
    assert assert_running("beta", "one") == beta_id

with subtest("aggregate update recovers when the local registry returns"):
    machine.succeed("systemctl start docker-registry")
    machine.wait_for_open_port(5000)
    machine.succeed("systemctl start compose-update")
    assert_running("alpha", "two")
    assert assert_running("beta", "two") != beta_id
    assert_environment("reloaded")
    for unit in ("compose-alpha-update", "compose-beta-update", "compose-update"):
        assert machine.succeed(f"systemctl show {unit} -p Result --value").strip() == (
            "success"
        )

with subtest("final stop leaves no Compose containers or shared network"):
    machine.succeed("systemctl stop compose-alpha")
    assert_clean()
